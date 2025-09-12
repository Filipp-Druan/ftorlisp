const std = @import("std");
const root = @import("root.zig");

pub const Symbol = struct {
    name: []const u8,

    pub fn new(alloc: std.mem.Allocator, name: []const u8) !*Symbol {
        const sym_mem = try alloc.create(Symbol);
        const name_mem = try alloc.dupe(u8, name);
        sym_mem.* = .{
            .name = name_mem,
        };
        return sym_mem;
    }
};

pub const SymMan = struct {
    map: Map,
    alloc: std.mem.Allocator,

    const Map = std.StringHashMap(*Symbol);

    pub fn init(alloc: std.mem.Allocator) SymMan {
        const map = Map.init(alloc);
        return .{
            .map = map,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *SymMan) void {
        self.map.deinit();
    }

    pub fn intern(self: *SymMan, name: []const u8) !*Symbol {
        var map = &self.map;

        const sym = map.get(name);
        if (sym) |sym_ptr| {
            return sym_ptr;
        } else {
            const new_sym = try Symbol.new(self.alloc, name);
            try map.put(name, new_sym);
            return new_sym;
        }
    }
};
