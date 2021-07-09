const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

const draw = @import("pixel_draw.zig");
const Texture = draw.Texture;
usingnamespace draw.vector_math;

pub const Block = struct {
    id: u16 = 0,
    texture: draw.Texture,
};

pub const Chunk = struct {
    block_data: [size * size * height]u16,
    light_data: [size * size * height]u8,

    pub const size = 16;
    pub const height = 256;

    pub inline fn setBlockData(chunk: *Chunk, x: u32, y: u32, z: u32, value: u16) void {
        chunk.block_data[x + z * size + y * size * size] = value;
    }

    pub inline fn setLightData(chunk: *Chunk, x: u32, y: u32, z: u32, value: u8) void {
        chunk.light_data[x + z * size + y * size * size] = value;
    }

    pub inline fn getBlockData(chunk: *Chunk, x: u32, y: u32, z: u32) u16 {
        return chunk.block_data[x + z * size + y * size * size];
    }

    pub inline fn getLightData(chunk: *Chunk, x: u32, y: u32, z: u32) u8 {
        return chunk.light_data[x + z * size + y * size * size];
    }

    pub inline fn posFromI(i: usize, x: *u32, y: *u32, z: *u32) void {
        x.* = @intCast(u32, i % size);
        z.* = @intCast(u32, (i / size) % size);
        y.* = @intCast(u32, i / (size * size));
    }

    pub fn init() Chunk {
        var result: Chunk = undefined;

        for (result.block_data) |*it| {
            it.* = 0;
        }

        for (result.light_data) |*it| {
            it.* = 255;
        }

        var z: u32 = 0;
        while (z < size) : (z += 1) {
            var x: u32 = 0;
            while (x < size) : (x += 1) {
                var y: u32 = x / 8 + z / 4;
                result.setBlockData(x, y, z, 1);
            }
        }

        return result;
    }
};

var block_list: [256]Block = undefined;

pub fn initBlockList(al: *Allocator) !void {
    block_list[0].id = 0;
    block_list[0].texture = try draw.textureFromTgaData(al, @embedFile("../assets/potato.tga"));

    var i: u16 = 1;
    while (i < block_list.len) : (i += 1) {
        block_list[i].id = i;
        block_list[i].texture = block_list[0].texture;
    }
}
