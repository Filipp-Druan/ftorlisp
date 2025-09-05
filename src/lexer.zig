const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const assert = std.debug.assert;

const CodePoint = code_point.CodePoint;
const CodeIter = code_point.Iterator;

pub const Coords = struct {
    file: []const u8,
    line: usize,
    char: usize,

    pub fn init(file: []const u8) Coords {
        return .{ .file = file, .line = 1, .char = 1 };
    }
    pub fn make(line: usize, char: usize) Coords {
        return .{ .line = line, .char = char };
    }
};

pub const TokenStart = struct {
    coords: Coords,
    start_byte: usize,
};

pub const Token = struct {
    tag: TokenTag,
    str: []const u8,
    coords: Coords,
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
    coords: Coords,

    pub fn init(code_iter: CodeIter, file: []const u8, pd: PropsData) Lexer {
        return Lexer{
            .code_iter = code_iter,
            .pd = pd,
            .coords = Coords.init(file),
        };
    }

    pub fn initFromString(str: []const u8, file: []const u8, pd: PropsData) Lexer {
        return Lexer.init(CodeIter{ .bytes = str }, file, pd);
    }

    pub fn next(self: *Lexer) Token {
        return self.readNext();
    }

    fn readNext(self: *Lexer) Token {
        self.skipWhitespace();

        switch (self.readEof()) {
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
        self.coords.line += 1;
        self.coords.char = 1;
    }

    fn tokenStart(self: *Lexer) TokenStart {
        return .{
            .coords = self.coords,
            .start_byte = self.code_iter.i,
        };
    }

    fn pointForward(self: *Lexer, point: ?CodePoint) void {
        if (isNewLine(point)) {
            self.lineFeed();
        } else {
            self.coords.char += 1;
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        var code = &self.code_iter;
        while (isWhitespace(code.peek(), self.pd)) {
            self.pointForward(code.next());
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
                .coords = self.coords,
            } };
        }
    }

    fn readError(self: *Lexer) Token {
        return Token{
            .tag = .Error,
            .str = "",
            .coords = self.coords,
        };
    }

    const PointPredicate = fn (?CodePoint, PropsData) bool;

    fn readByPredicate(self: *Lexer, pred: PointPredicate, tag: TokenTag) Res {
        var code = self.code_iter; // Пока не дописал эту функцию.
        const start_coords = self.coords;
        const start_byte = code.i;

        const point = code.next();
        if (pred(point, self.pd)) {
            self.code_iter = code;
            self.pointForward(point);
            return Res.success(tag, code, start_coords, start_byte);
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
};

const Res = union(enum) {
    tok: Token,
    fail,

    pub fn success(tag: TokenTag, code: CodeIter, coords: Coords, start: u32) Res {
        return .{ .tok = .{
            .tag = tag,
            .str = getSliceToNext(code, start),
            .coords = coords,
        } };
    }
};

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

    assert(res.coords.line == 1);
    assert(res.coords.char == 4);
}

fn tokenCmp(token: Token, tag: TokenTag, str: []const u8, line: usize, char: usize) bool {
    return (token.tag == tag) and
        std.mem.eql([]const u8, str, token.str) and
        token.coords.line == line and
        token.coords.char == char;
}

test "Lexer brackets" {
    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit(std.testing.allocator);

    var lexer = Lexer.initFromString("([])", "test.lisp", pd);
    const res_1 = lexer.next();
    const res_2 = lexer.next();
    const res_3 = lexer.next();
    const res_4 = lexer.next();
}
