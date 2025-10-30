const std = @import("std");
const root = @import("root.zig");

const Ty = root.types.Ty;
const symbols = root.symbols;
const Symbol = symbols.Symbol;

// В этом файле реализована таблица имён.
// В ней соотносятся имена сущностей и их типы.
// Таблица представляет из себя пространство имён.
//
// У таблицы есть родительская область видимости.

pub const Scope = struct {
    parent: ?*Scope,
    entries: std.AutoHashMap(*Symbol, Ty),
};
