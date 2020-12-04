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
    
    pub fn init() Chunck {
        var result: Cunck = undefined;
        
        for (result.block_data) |*it| {
            it.* = 0;
        }
        
        for (result.light_data) |*it| {
            it.* = 255;
        }
    }
}

var block_list: [256]Block = undefined;

pub fn initBlockList(al: *Allocator) !void {
    block_list[0].id = 0;
    block_list[0].texture = try draw.textureFromTgaData(al, @embedFile("../assets/potato.tga"));
    
    var i: u16 = 1;
    while (i < block_list) : (i += 1) {
        block_list[i].id = i;
        block_list[i].texture = block_list[0].texture;
    }
}
