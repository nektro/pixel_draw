const std = @import("std");
// Utility functions
//

/// Read a int from a file
pub fn readIntFromFile(comptime T: type, file: std.fs.File) !T {
    var buf = [_]u8{0} ** @sizeOf(T);
    _ = try file.readAll(buf[0..]);
    return std.mem.readIntLittle(T, buf[0..]);
}

/// write a int @n to a file
pub fn writeIntToFile(file: std.fs.File, n: anytype) !void {
    try file.writeAll(std.mem.toBytes(n)[0..]);
}

/// Read a int from a file on @pos
pub fn readIntFromFileOnPos(comptime T: type, file: std.fs.File, pos: u64) !T {
    const oldPos = try file.getPos();
    try file.seekTo(pos);
    var buf = [_]u8{0} ** @sizeOf(T);
    _ = try file.readAll(buf[0..]);
    try file.seekTo(oldPos);
    return std.mem.readIntLittle(T, buf[0..]);
}

/// write a int @n to a file on @pos
pub fn writeIntToFileOnPos(file: std.fs.File, n: anytype, pos: u64) !void {
    const oldPos = try file.getPos();
    try file.seekTo(pos);
    try file.writeAll(std.mem.toBytes(n)[0..]);
    try file.seekTo(oldPos);
}

pub fn swap(a: anytype, b: anytype) void {
    comptime if (@TypeOf(a) != @TypeOf(b))
        @compileError("Trying to swap diferent types\n");

    var tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// #TODO(samuel): Change to use only one sort function
pub fn quickSort(
    comptime T: type,
    array: []T,
    lesst_func: fn (a: T, b: T) bool,
    greatt_func: fn (a: T, b: T) bool,
) void {
    var i: isize = 0;
    var j: isize = @intCast(isize, array.len - 1);
    var pivo = array[array.len / 2];
    while (i <= j) {
        while (lesst_func(array[@intCast(usize, i)], pivo)) i += 1;
        while (greatt_func(array[@intCast(usize, j)], pivo)) j -= 1;

        if (i <= j) {
            swap(&array[@intCast(usize, i)], &array[@intCast(usize, j)]);
            i += 1;
            j -= 1;
        }
    }
    if (0 < j)
        quickSort(T, array[0..@intCast(usize, (j + 1))], lesst_func, greatt_func);
    if (i < array.len)
        quickSort(T, array[@intCast(usize, (i))..], lesst_func, greatt_func);
}

/// This is a type return function that create a FixedSizeString type
/// this create a string on the stack with the max size 'size', and an lenth
/// this is usefull when you need a string on a struct and dont want to make
/// heap allocations, and you can copy the string with ease #CHECK
pub fn FixedSizeString(comptime size: usize) type {
    return struct {
        data: [size]u8 = [_]u8{0} ** size,
        len: usize = 0,
    };
}

pub inline fn emptyFixedString(comptime size: usize) FixedSizeString(size) {
    return createFixedString(size, ([_]u8{0} ** size)[0..]);
}

/// recive a FixedSizeString and return a []const u8 slice with its size
/// if you pass a pointer to a FixedSizeString it will return a []u8
pub inline fn fixedStrToSlice(str: anytype) switch (@typeInfo(@TypeOf(str))) {
    .Pointer => []u8,
    else => []const u8,
} {
    return str.data[0..str.len];
}

pub fn createFixedString(
    comptime size: usize,
    str: []const u8,
) FixedSizeString(size) {
    var result: FixedSizeString(size) = undefined;
    result.len = str.len;
    for (str) |c, i| {
        if (i >= size) break;
        result.data[i] = c;
    }
    return result;
}

/// return the current line and advances the buffer to the next
pub fn nextLineSlice(slice: *[]u8) []u8 {
    if (slice.len == 0) return slice.*;

    var i: usize = 0;
    while (i < slice.len and slice.*[i] != '\n') {
        i += 1;
    }

    var result = slice.*[0..i];

    if (i > 0 and slice.*[i - 1] == '\r') {
        result.len -= 1;
    }
    slice.* = slice.*[i + 1 ..];

    return result;
}

pub fn removeLeadingSpaces(slice: *[]u8) void {
    if (slice.len == 0) return;
    var i: usize = 0;
    while (slice.*[i] == ' ' or slice.*[i] == '\t') {
        i += 1;
    }
    slice.* = slice.*[i..];
}

pub fn removeTrailingSpaces(slice: *[]u8) void {
    if (slice.len == 0) return;
    var i: usize = slice.len - 1;
    while (slice.*[i] == ' ' or slice.*[i] == '\t') {
        i -= 1;
    }
    slice.* = slice.*[0 .. i + 1];
}

/// Return the token and advances the buffer
pub fn getToken(slice: *[]u8, separator: u8) []u8 {
    if (slice.len == 0) return slice.*;

    var i: usize = 0;
    while (i < slice.len and slice.*[i] != separator) {
        i += 1;
        if (i >= slice.len) {
            return slice.*;
        }
    }

    var result = slice.*[0..i];
    slice.* = slice.*[i + 1 ..];
    return result;
}

pub fn hasChar(str: []const u8, char: u8) bool {
    for (str) |c| if (c == char) return true;
    return false;
}

/// Compares two slices
pub fn sliceCmp(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a) |it, index| {
        if (it != b[index]) return false;
    }
    return true;
}

/// Compares two strings
pub inline fn strCmp(a: []const u8, b: []const u8) bool {
    return sliceCmp(u8, a, b);
}

/// Compares two FixedSizeString of any size
pub fn fixStrCmp(a: anytype, b: anytype) bool {
    if (a.len != b.len) return false;

    var index: usize = 0;
    while (index > a.len) : (index += 1) {
        if (a.data[index] != b.data[index]) return false;
    }

    return true;
}

/// Return a random float from 0 to 1
var prng = std.rand.DefaultPrng.init(0);
pub inline fn randomFloat(comptime T: type) T {
    return prng.random.float(T);
}

pub inline fn randomInt(comptime T: type) T {
    return prng.random.int(T);
}
