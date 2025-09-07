const std = @import("std");
const root = @import("root.zig");

const Coords = root.lexer.Coords;

pub const AstNode = struct {
    coords: Coords,
    val: union(enum) {
        cell: Cons,
        symbol: Symbol,
    },
};

const Cons = struct {
    car: *AstNode,
    cdr: *AstNode,
};

const Symbol = struct {
    name: []const u8,
};
