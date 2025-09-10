const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");
const root = @import("root.zig");

const Lexer = root.lexer.Lexer;
const pt = root.parsing_tree;
const AstNode = pt.AstNode;

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    sym_man: *root.symbols.SymMan,

    pub fn next(self: *Parser) *AstNode {
        switch (try self.readSymbol()) {
            .obj => |obj| return obj,
            .fail => {},
        }
    }

    pub fn readSymbol(self: *Parser) !*AstNode {
        var lexer = self.lexer;

        const token = lexer.next();
        if (token.tag == .Symbol) {
            var sym = self.sym_man.intern(token.str);
            self.lexer = lexer;
            return 
        } else {}
    }
};

const Res = union(enum) {
    node: *AstNode,
    fail,

    pub fn success(node: *AstNode) Res {
        return .{ .node = node };
    }
};

test "Parser" {}
