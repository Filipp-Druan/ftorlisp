const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");
const root = @import("root.zig");

const Lexer = root.lexer.Lexer;
const ast = root.ast;
const AstNode = ast.AstNode;

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    symbols: *ast.SymbolTable,
    
    pub fn next(self: *Parser) *AstNode {
        
    }
};
