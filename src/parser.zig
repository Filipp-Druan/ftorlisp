const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");
const root = @import("root.zig");

const assert = std.debug.assert;

const Lexer = root.lexer.Lexer;
const pt = root.parsing_tree;
const List = root.parsing_tree.List;
const Node = pt.Node;
const SymMan = root.symbols.SymMan;

const ParsingError = error{
    CantParse,
};

pub const Parser = struct {
    lexer: Lexer,
    alloc: std.mem.Allocator,
    sym_man: *SymMan,

    pub fn initFromString(alloc: std.mem.Allocator, str: []const u8, file: []const u8, sym_man: *SymMan, pd: PropsData) Parser {
        const lexer = Lexer.initFromString(str, file, pd);

        return .{ .lexer = lexer, .alloc = alloc, .sym_man = sym_man };
    }

    pub fn next(self: *Parser) anyerror!*Node {
        switch (try self.readInteger()) {
            .node => |node| return node,
            .fail => {},
        }
        switch (try self.readSymbol()) {
            .node => |node| return node,
            .fail => {},
        }
        switch (try self.readList()) {
            .node => |node| return node,
            .fail => {},
        }
        return ParsingError.CantParse;
    }

    fn readSymbol(self: *Parser) !Res {
        var lexer = self.lexer;

        const token = lexer.next();
        if (token.tag == .Symbol) {
            const sym = try self.sym_man.intern(token.str);
            self.lexer = lexer;
            const node = try Node.newSymbol(sym, token.position, self.alloc);
            return Res.success(node);
        } else {
            return Res.fail;
        }
    }

    fn readInteger(self: *Parser) !Res {
        var lexer = self.lexer;

        const token = lexer.next();
        if (token.tag == .Number) {
            const num = parseInteger(token.str);
            self.lexer = lexer;
            const node = try Node.newInteger(num, token.position, self.alloc);
            return Res.success(node);
        } else {
            return Res.fail;
        }
    }

    fn readList(self: *Parser) !Res {
        var parser = self.*;

        var token = parser.lexer.next();

        if (token.tag != .OpenBracket) {
            return Res.fail;
        }

        const pos = token.position;
        var list = List.init(self.alloc); // Тут есть опасность ошибки.

        while (true) {
            token = parser.lexer.peek();

            switch (token.tag) {
                .CloseBracket => {
                    _ = parser.lexer.next();
                    self.* = parser;
                    return Res.success(try Node.newList(list, pos, self.alloc));
                },
                .Eof => {
                    return Res.fail;
                },
                .Error => {
                    return Res.fail;
                },
                else => {
                    const node = try parser.next();
                    try list.append(node);
                    continue;
                },
            }
        }
    }
};

const Res = union(enum) {
    node: *Node,
    fail,

    pub fn success(node: *Node) Res {
        return .{ .node = node };
    }
};

/// Эта функция из строки получает записанное в ней число.
/// Она опирается на контракты, которая обеспечивает лексер, что строка не пустая, и не содержит
/// никаких других символов, кроме минуса и цифр;
fn parseInteger(str: []const u8) i64 {
    const work_str = if (str[0] == '-') str[1..] else str;
    const is_neg = str[0] == '-';

    var res: i64 = 0;
    for (work_str) |digit| {
        res = res * 10 + digitToNum(digit);
    }

    return if (is_neg) -res else res;
}

fn digitToNum(digit: u8) u8 {
    return digit - 48;
}

test "Parser" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const alloc = arena.allocator();
    var sym_man = root.symbols.SymMan.init(alloc);
    defer arena.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    var parser = Parser.initFromString(alloc, "(first second third) -25", "test", &sym_man, pd);

    const list = try parser.next();
    std.debug.assert(list.val == .list);
    std.debug.assert(list.val.list.items.len == 3);

    std.debug.assert(list.val.list.items[0].val.symbol == try sym_man.intern("first"));
    std.debug.assert(list.val.list.items[1].val.symbol == try sym_man.intern("second"));
    std.debug.assert(list.val.list.items[2].val.symbol == try sym_man.intern("third"));

    const num = try parser.next();

    assert(num.val == .integer);
    assert(num.val.integer == -25);
}

test "parseInteger" {
    assert(parseInteger("123") == 123);
    assert(parseInteger("-123") == -123);
}
