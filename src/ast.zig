const std = @import("std");
const root = @import("root.zig");

const PropsData = @import("PropsData");

const symbols = root.symbols;
const Symbol = symbols.Symbol;
const SymMan = symbols.SymMan;

const assert = std.debug.assert;

const ParsingNode = root.parsing_tree.Node;
const Position = root.lexer.Position;

// В этом файле я создаю структуры, в которых хранятся различные выражения.
// Определения функций. Присваивания. Вызовы функций.

pub const AST = union(enum) {
    begin: Begin,
    let: Let,
    name: *Symbol,
    integer: i64,
    call: Call,
    err: ASTError,
};

pub const FormName = enum { Let, Expr, Begin, Call };

pub const ErrorTag = enum { BadLen, BadName, KeyInExpr, SimpleValInBlock };

pub const ASTError = struct {
    form: FormName,
    tag: ErrorTag,
    pos: Position,

    pub fn new(alloc: std.mem.Allocator, form: FormName, tag: ErrorTag, pos: Position) !*AST {
        const ast = try alloc.create(AST);
        ast.* = .{ .err = .{ .form = form, .tag = tag, .pos = pos } };
        return ast;
    }
};

pub const ASTList = std.ArrayList(*AST);

// Это Бегин -- блок кода. В нём могут быть любые выражения и стейтменты.
pub const Begin = struct {
    body: ASTList,
};

pub const Let = struct {
    name: *Symbol,
    val: *AST,
};

pub const Call = struct {
    fun: *Symbol,
    args: ASTList,
};

pub fn pass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    switch (node.val) {
        .symbol => |sym| {
            const ast = try alloc.create(AST);
            ast.* = .{ .name = sym };
            return ast;
        },
        .integer => |num| {
            const ast = try alloc.create(AST);
            ast.* = .{ .integer = num };
            return ast;
        },
        .list => {
            return listPass(node, alloc, sym_man);
        },
    }
}

pub fn listPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    assert(node.val == .list);
    const head = node.val.list.items[0];
    if (head.val == .symbol) {
        const sym = head.val.symbol;
        if (sym == sym_man.spec.let) return letPass(node, alloc, sym_man);
        if (sym == sym_man.spec.begin) return beginPass(node, alloc, sym_man);

        return callPass(node, alloc, sym_man);
    } else {
        assert(false); // У нас пока не может на месте оператора быть список.
        unreachable;
    }
}

fn letPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    assert(node.val == .list);
    assert(node.val.list.items[0].val.symbol == sym_man.spec.let);

    const items = node.val.list.items;
    // let принимает ровно два аргумента.
    if (items.len != 3) {
        return ASTError.new(alloc, .Let, .BadLen, node.position);
    }

    // Имя аргумента пока только символ. Аннотацию типа мы сделаем позднее.
    if (items[0].val != .symbol) {
        return ASTError.new(alloc, .Let, .BadName, items[1].position);
    }

    const ast = try alloc.create(AST);
    ast.* = .{ .let = .{ .name = items[1].val.symbol, .val = try exprPass(items[2], alloc, sym_man) } };
    return ast;
}

fn beginPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) anyerror!*AST {
    assert(node.val == .list);
    assert(node.val.list.items[0].val.symbol == sym_man.spec.begin);

    const items = node.val.list.items;

    var list = ASTList.init(alloc);

    for (items[1..]) |current_node| {
        switch (current_node.val) {
            .list => {
                try list.append(try pass(current_node, alloc, sym_man));
            },
            else => {
                return ASTError.new(alloc, .Begin, .SimpleValInBlock, current_node.position);
            },
        }
    }
    const ast = try alloc.create(AST);
    ast.* = .{ .begin = .{ .body = list } };
    return ast;
}

fn callPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) anyerror!*AST {
    assert(node.val == .list);
    const items = node.val.list.items;

    const operator = items[0];

    switch (operator.val) {
        .symbol => |sym| {
            if (isKey(sym, sym_man)) {
                return ASTError.new(alloc, .Call, .BadName, operator.position);
            }
        },
        else => return ASTError.new(alloc, .Call, .BadName, operator.position),
    }

    var arg_exprs = ASTList.init(alloc);

    for (items[1..]) |current_node| {
        const expr = try exprPass(current_node, alloc, sym_man);
        try arg_exprs.append(expr);
    }

    const ast = try alloc.create(AST);
    ast.* = .{ .call = .{ .fun = operator.val.symbol, .args = arg_exprs } };
    return ast;
}

fn isKey(sym: *Symbol, sym_man: *SymMan) bool {
    return sym == sym_man.spec.begin or
        sym == sym_man.spec.let;
}

// В языке есть выражения, которые возвращают значения. В них не может быть ключвых слов, только операторы и
// вызовы функций, переменные и литералы.
fn exprPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    switch (node.val) {
        .symbol => |sym| {
            const ast = try alloc.create(AST);
            ast.* = .{ .name = sym };
            return ast;
        },
        .integer => |num| {
            const ast = try alloc.create(AST);
            ast.* = .{ .integer = num };
            return ast;
        },
        .list => |_| {
            return callPass(node, alloc, sym_man);
        },
    }
}

test "Pass" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const alloc = arena.allocator();
    var sym_man = try root.symbols.SymMan.init(alloc);
    defer arena.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    var parser = root.parser.Parser.initFromString(alloc, "(begin (let num 25) (print num))", "test", &sym_man, pd);
    const node = try parser.next();
    assert(node.val == .list);
    const ast = try pass(node, alloc, &sym_man);

    assert(ast.* == .begin);
    assert(ast.begin.body.items.len == 2);

    const let = ast.begin.body.items[0];

    assert(let.* == .let);
    assert(let.*.let.name == try sym_man.intern("num"));
    assert(let.*.let.val.integer == 25);

    const call = ast.begin.body.items[1];

    assert(call.* == .call);
    assert(call.call.fun == try sym_man.intern("print"));
    assert(call.call.args.items[0].name == try sym_man.intern("num"));
}
