const std = @import("std");
const root = @import("root.zig");

const symbols = root.symbols;
const Symbol = symbols.Symbol;
const SymMan = symbols.SymMan;

const assert = std.debug.assert;

const ParsingNode = root.parsing_tree.Node;
const Position = root.lexer.Position;

// В этом файле я создаю структуры, в которых хранятся различные выражения.
// Определения функций. Присваивания. Вызовы функций.

pub const AST = union(enum) {
    fun_def: FunDef,
    let: Let,
    name: *Symbol,
    integer: i64,
    err: ASTError,
};

pub const FormName = enum { Let, Define };

pub const ErrorTag = enum { BadLen, BadName };

pub const ASTError = struct {
    form: FormName,
    tag: ErrorTag,
    pos: Position,
};

pub const ASTList = std.ArrayList(*AST);

// Это определение функции. У неё есть имя, возвращаемый тип и тело.
pub const FunDef = struct {
    name: *Symbol, // Аргументы добавим попозже.
    res_type: *Symbol,
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

    }
}

fn letPass(node: *ParsingNode, alloc: std.mem.Allocator, sym_man: *SymMan) !*AST {
    assert(node.val == .list);
    assert(node.val.list.items[0] == sym_man.spec.let);
    const ast = try alloc.create(AST);

    const items = node.val.list.items;
    // let принимает ровно два аргумента.
    if (items.len != 3) {
        ast.* = .{ .err = .{ .form = .Let, .tag = .BadLen, .pos = node.position } };
        return ast;
    }

    // Имя аргумента пока только символ. Аннотацию типа мы сделаем позднее.
    if (items[0].val != .symbol) {
        ast.* = .{ .err = .{ .form = .Let, .tag = .BadName, .pos = items[1].position } };
        return ast;
    }

    ast.* = .{ .let = .{ .name = items[1].val.symbol, .val = exprPass(items[2])} }
}
