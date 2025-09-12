const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const assert = std.debug.assert;

const CodePoint = code_point.CodePoint;
const CodeIter = code_point.Iterator;

pub const Position = struct {
    file: []const u8,
    line: usize,
    char: usize,

    pub fn init(file: []const u8) Position {
        return .{ .file = file, .line = 1, .char = 1 };
    }
    pub fn make(line: usize, char: usize) Position {
        return .{ .line = line, .char = char };
    }
};

pub const TokenStart = struct {
    position: Position,
    start_byte: u32,
};

pub const Token = struct {
    tag: TokenTag,
    str: []const u8,
    position: Position,

    pub fn print(token: Token) void {
        std.debug.print("Token:\n tag:{s} str: {s}\n  line: {}\n  char: {}", .{
            @tagName(token.tag),
            token.str,
            token.position.line,
            token.position.char,
        });
    }
};

pub const TokenTag = enum {
    Eof,
    Error,
    Symbol,
    Number,
    String,
    OpenBracket,
    CloseBracket,
    Quote,
    Dot,
};

pub const Lexer = struct {
    code_iter: CodeIter,
    pd: PropsData,
    position: Position,

    pub fn init(code_iter: CodeIter, file: []const u8, pd: PropsData) Lexer {
        return Lexer{
            .code_iter = code_iter,
            .pd = pd,
            .position = Position.init(file),
        };
    }

    pub fn initFromString(str: []const u8, file: []const u8, pd: PropsData) Lexer {
        return Lexer.init(CodeIter{ .bytes = str }, file, pd);
    }

    pub fn next(self: *Lexer) Token {
        return self.readNext();
    }

    pub fn peek(self: *Lexer) Token {
        var lexer = self.*;
        return Lexer.readNext(&lexer);
    }

    fn readNext(self: *Lexer) Token {
        self.skipWhitespace();

        switch (self.readEof()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readInteger()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readSymbol()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readOpenBracket()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readCloseBracket()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readQuote()) {
            .tok => |token| return token,
            .fail => {},
        }

        return self.readError();
    }

    fn lineFeed(self: *Lexer) void {
        self.position.line += 1;
        self.position.char = 1;
    }

    fn tokenStart(self: *Lexer) TokenStart {
        return .{
            .position = self.position,
            .start_byte = self.code_iter.i,
        };
    }

    fn stepForward(self: *Lexer, point: ?CodePoint) void {
        if (isNewLine(point)) {
            self.lineFeed();
        } else {
            self.position.char += 1;
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        var code = &self.code_iter;
        while (isWhitespace(code.peek(), self.pd)) {
            self.stepForward(code.next());
        }
    }

    fn readEof(self: *Lexer) Res {
        var code = self.code_iter;
        if (code.next()) |_| {
            return Res.fail;
        } else {
            return .{ .tok = Token{
                .tag = .Eof,
                .str = "",
                .position = self.position,
            } };
        }
    }

    fn readError(self: *Lexer) Token {
        return Token{
            .tag = .Error,
            .str = "",
            .position = self.position,
        };
    }

    const PointPredicate = fn (?CodePoint, PropsData) bool;

    fn readByPredicate(self: *Lexer, pred: PointPredicate, tag: TokenTag) Res {
        var code = self.code_iter; // Пока не дописал эту функцию.
        const start = self.tokenStart();

        const point = code.next();
        if (pred(point, self.pd)) {
            self.code_iter = code;
            self.stepForward(point);
            return Res.success(tag, code, start);
        } else {
            return Res.fail;
        }
    }

    fn readQuote(self: *Lexer) Res {
        return self.readByPredicate(isQuote, .Quote);
    }

    fn readOpenBracket(self: *Lexer) Res {
        return self.readByPredicate(isOpenBracket, .OpenBracket);
    }

    fn readCloseBracket(self: *Lexer) Res {
        return self.readByPredicate(isCloseBracket, .CloseBracket);
    }

    fn readSymbol(self: *Lexer) Res {
        var code = self.code_iter;
        const start = self.tokenStart();

        const point = code.next();
        if (isSymbolStartPoint(point, self.pd)) {
            self.stepForward(point);
        } else {
            return Res.fail;
        }

        while (isSymbolBodyPoint(code.peek(), self.pd)) {
            self.stepForward(code.next());
        }

        self.code_iter = code;

        return Res.success(.Symbol, code, start);
    }
    fn readInteger(self: *Lexer) Res {
        var code = self.code_iter;
        const start = self.tokenStart();

        const point = code.next();
        if (cmp(point, '-')) {
            if (isDecimal(code.peek(), self.pd)) {
                self.stepForward(point);
                self.stepForward(code.next());
            } else {
                return Res.fail;
            }
        } else if (isDecimal(point, self.pd)) {
            self.stepForward(point);
        } else {
            return Res.fail;
        }

        while (isDecimal(code.peek(), self.pd)) {
            self.stepForward(code.next());
        }

        self.code_iter = code;

        return Res.success(.Number, code, start);
    }
};

const Res = union(enum) {
    tok: Token,
    fail,

    pub fn success(tag: TokenTag, code: CodeIter, start: TokenStart) Res {
        return .{ .tok = .{
            .tag = tag,
            .str = getSliceToNext(code, start.start_byte),
            .position = start.position,
        } };
    }
};
// TODO: Нужно разобраться с типами старта. Что-то тут не так.
fn getSlice(code: CodeIter, start: u32, end: u32) []const u8 {
    return code.bytes[start..end];
}

fn getSliceToNext(code: CodeIter, start: u32) []const u8 {
    return getSlice(code, start, posOfNext(code));
}

fn posOfNext(code: CodeIter) u32 {
    return code.i;
}

fn isNewLine(cp: ?CodePoint) bool {
    return cmp(cp, '\n');
}

fn isWhitespace(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        return pd.isWhitespace(point.code);
    } else return false;
}

fn isDecimal(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        return pd.isDecimal(point.code);
    } else return false;
}

fn isSymbolStartPoint(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        const code = point.code;
        return pd.isAlphabetic(code) or
            code == '+' or
            code == '-' or
            code == '*' or
            code == '/' or
            code == '<' or
            code == '=' or
            code == '>';
    } else {
        return false;
    }
}

fn isSymbolBodyPoint(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        const code = point.code;

        return isSymbolStartPoint(cp, pd) or pd.isDecimal(code);
    } else {
        return false;
    }
}

fn isQuote(cp: ?CodePoint, pd: PropsData) bool {
    _ = pd;
    return cmp(cp, '\'');
}

fn isOpenBracket(cp: ?CodePoint, pd: PropsData) bool {
    _ = pd;
    return cmp(cp, '(') or cmp(cp, '[');
}

fn isCloseBracket(cp: ?CodePoint, pd: PropsData) bool {
    _ = pd;
    return cmp(cp, ')') or cmp(cp, ']');
}

fn cmp(cp: ?CodePoint, char: u21) bool {
    if (cp) |point| {
        const code = point.code;
        return code == char;
    } else {
        return false;
    }
}

test "getSliceToNext" {
    var iter = CodeIter{ .bytes = "abcd" };

    _ = iter.next();

    const start = iter.i;
    _ = iter.next();
    _ = iter.next();

    const res = getSliceToNext(iter, start);

    const ref = "bc";

    try std.testing.expectEqualStrings(ref, res);
}

test "Lexer.init" {
    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    _ = Lexer.initFromString("()", "test.lisp", pd);
}

test "Lexer skipWhitespace" {
    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    var lexer = Lexer.initFromString("   ", "test.lisp", pd);
    const res = lexer.next();

    assert(res.position.line == 1);
    assert(res.position.char == 4);
}

fn tokenCmp(token: Token, tag: TokenTag, str: []const u8, line: usize, char: usize) bool {
    return (token.tag == tag) and
        std.mem.eql(u8, str, token.str) and
        token.position.line == line and
        token.position.char == char;
}

test "Lexer next" {
    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    var lexer = Lexer.initFromString("([- -5\n -hello])", "test.lisp", pd);
    const res_1 = lexer.next();
    const res_2 = lexer.next();
    const res_3 = lexer.next();
    const res_4 = lexer.next();
    const res_5 = lexer.next();
    const res_6 = lexer.next();
    const res_7 = lexer.next();

    assert(tokenCmp(res_1, .OpenBracket, "(", 1, 1));
    assert(tokenCmp(res_2, .OpenBracket, "[", 1, 2));
    assert(tokenCmp(res_3, .Symbol, "-", 1, 3));
    assert(tokenCmp(res_4, .Number, "-5", 1, 5));
    assert(tokenCmp(res_5, .Symbol, "-hello", 2, 2));
    assert(tokenCmp(res_6, .CloseBracket, "]", 2, 8));
    assert(tokenCmp(res_7, .CloseBracket, ")", 2, 9));
}
