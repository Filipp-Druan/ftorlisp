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
    spec: struct {
        let: *Symbol,
        begin: *Symbol,
    },

    const Map = std.StringHashMap(*Symbol);

    pub fn init(alloc: std.mem.Allocator) !SymMan {
        const map = Map.init(alloc);
        var sym_man: SymMan = undefined;

        sym_man.alloc = alloc;
        sym_man.map = map;
        try sym_man.initSpec();

        return sym_man;
    }

    pub fn initSpec(self: *SymMan) !void {
        self.spec.let = try self.intern("let");
        self.spec.begin = try self.intern("begin");
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
