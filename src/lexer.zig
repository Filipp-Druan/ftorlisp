const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const CodePoint = code_point.CodePoint;
const CodeIter = code_point.Iterator;

pub const Token = struct {
    tag: TokenTag,
    str: []const u8,
    file: []const u8,
    line: usize,
    char_pos: usize,
};


pub const TokenTag = enum {
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
    line: usize,
    char_pos: usize,
    file: []const u8,
    
    
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