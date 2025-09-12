//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const root = @import("root.zig");

pub fn main() !void {}

test "main test" {
    std.testing.refAllDecls(root.lexer);
    std.testing.refAllDecls(root.parser);
}
