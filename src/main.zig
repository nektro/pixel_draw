// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

usingnamespace @import("util.zig");
const draw = @import("pixel_draw.zig");
const Texture = draw.Texture;

// === Global Variables ===
var main_allocator: *Allocator = undefined;
var font: draw.BitmapFont = undefined;
var potato: Texture = undefined;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    main_allocator = &gpa.allocator;
    
    try draw.init(&gpa.allocator, 800, 600, start, update);
    end();
}

fn start() void {
    font = .{
        .texture = draw.textureFromTgaData(main_allocator,@embedFile("../assets/font.tga"))catch unreachable,
        .font_size_x = 12,
        .font_size_y = 16,
        .character_spacing = 11,
    };
    potato = draw.textureFromTgaData(main_allocator, @embedFile("../assets/potato.tga")) catch unreachable;
}

fn end() void {
    main_allocator.free(font.texture.raw);
    main_allocator.free(potato.raw);
}

var print_buff: [512]u8 = undefined;

fn update(delta: f32) void {
    draw.fillScreenWithRGBColor(100, 100, 100);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}",
                                      .{ 1 / delta, delta }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
    
    var mx = [_]f32{-0.8, -0.8, 0.8};
    var my = [_]f32{0.8, -0.8, -0.0};
    var mz = [_]f32{1.0, 0.5, 0.0};
    var mi = [_]u32{0, 1, 2};
    var mu = [_]f32{0.5, 0.0, 1.0};
    var mv = [_]f32{0.0, 1.0, 1.0};
    
    var mcolors = [_]draw.Color{
        draw.Color.c(1, 0, 0, 1),
        draw.Color.c(0, 1, 0, 1),
        draw.Color.c(0, 0, 1, 1),
    };
    
    var mesh = draw.Mesh {
        .x = &mx,
        .y = &my,
        .z = &mz,
        .i = &mi,
        .u = &mu,
        .v = &mv,
        .colors = &mcolors,
        .texture = potato,
    };
    
    draw.rasterMesh(mesh);
    
}
