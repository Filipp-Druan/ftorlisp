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
    err: ASTError,
};

pub const FormName = enum { Let, Expr, Begin };

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
        assert(false); // Мы не выбрали допустимый оператор
        unreachable;
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

// В языке есть выражения, которые возвращают значения. В них не может быть ключвых слов, только операторы и
// вызовы функций, переменные и литералы.
fn exprPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    _ = sym_man;
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
            assert(false); // Сложные выражения пока не реализованы.
            unreachable;
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

    var parser = root.parser.Parser.initFromString(alloc, "(begin (let num 25))", "test", &sym_man, pd);
    const node = try parser.next();
    assert(node.val == .list);
    const ast = try pass(node, alloc, &sym_man);

    assert(ast.* == .begin);
    assert(ast.begin.body.items.len == 1);
    const let = ast.begin.body.items[0];
    assert(let.* == .let);
    assert(let.*.let.name == try sym_man.intern("num"));
    assert(let.*.let.val.integer == 25);
}
