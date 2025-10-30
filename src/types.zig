const std = @import("std");
const root = @import("root.zig");

const symbols = root.symbols;
const Symbol = symbols.Symbol;

pub const Ty = struct {
    name: *Symbol,
    val: union(enum) {
        simple_ty: SimpleTy,
        fun_ty: FunTy,
    },
};

pub const SimpleTy = enum {
    int64,
};

pub const FunTy = struct {
    name: *Symbol,
    params: []Ty,
    ret: Ty,
};
