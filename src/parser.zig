const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");
const root = @import("root.zig");

const Lexer = root.lexer.Lexer;
const pt = root.parsing_tree;
const Node = pt.Node;

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    sym_man: *root.symbols.SymMan,

    pub fn next(self: *Parser) *Node {
        switch (try self.readSymbol()) {
            .obj => |obj| return obj,
            .fail => {},
        }
    }

    pub fn readSymbol(self: *Parser) !*Node {
        var lexer = self.lexer;

        const token = lexer.next();
        if (token.tag == .Symbol) {
            const sym = self.sym_man.intern(token.str);
            self.lexer = lexer;
            return Node.newSymbol(sym, token.position, self.allocator);
        } else {}
    }
};

const Res = union(enum) {
    node: *Node,
    fail,

    pub fn success(node: *Node) Res {
        return .{ .node = node };
    }
};

test "Parser" {}
