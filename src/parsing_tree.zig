const std = @import("std");
const root = @import("root.zig");

const symbols = root.symbols;
const Symbol = symbols.Symbol;

const Position = root.lexer.Position;

pub const Node = struct {
    position: Position,
    val: union(enum) {
        list: List,
        symbol: *Symbol,
        integer: i64,
    },

    pub fn newSymbol(sym: *Symbol, pos: Position, alloc: std.mem.Allocator) !*Node {
        const node = try alloc.create(Node);
        node.* = Node{ .position = pos, .val = .{ .symbol = sym } };
        return node;
    }

    pub fn newList(list: List, pos: Position, alloc: std.mem.Allocator) !*Node {
        const node = try alloc.create(Node);
        node.* = Node{ .position = pos, .val = .{ .list = list } };
        return node;
    }

    pub fn newInteger(int: i64, pos: Position, alloc: std.mem.Allocator) !*Node {
        const node = try alloc.create(Node);
        node.* = Node{ .position = pos, .val = .{ .integer = int } };
        return node;
    }
};

pub const List = std.ArrayList(*Node);
