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
    },

    pub fn newSymbol(sym: *Symbol, pos: Position, alloc: std.mem.Allocator) !*Node {
        const node = try alloc.create(Node);
        node.* = Node{ .position = pos, .val = .{ .symbol = sym } };
        return node;
    }
};

pub const List = std.ArrayList(*Node);
