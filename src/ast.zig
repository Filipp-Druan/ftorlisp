const std = @import("std");
const root = @import("root.zig");

const Coords = root.lexer.Coords;

pub const AstNode = struct {
    coords: Coords,
    val: union(enum) {
        cell: Cons,
        symbol: *Symbol,
    },
};

const Cons = struct {
    car: *AstNode,
    cdr: *AstNode,
};

const Symbol = struct {
    name: []const u8,

    pub fn new(alloc: std.mem.Allocator, name: []const u8) !Symbol {
        const name_mem = try alloc.dupe(u8, name);
        return .{
            .name = name_mem,
        };
    }
};

pub const SymbolTable = struct {
    map: Map,

    const Map = std.StringHashMap(*Symbol);

    pub fn init(alloc: std.mem.Allocator) SymbolTable {
        const map = Map.init(alloc);
        return .{
            .map = map,
        };
    }

    pub fn deinit(self: SymbolTable) void {
        self.map.deinit();
    }
};
