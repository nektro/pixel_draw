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
        .texture = draw.textureFromTgaData(main_allocator, @embedFile("../assets/font.tga")) catch unreachable,
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


const near: f32 = 0.1;
const far: f32 = 100.0;
const fov: f32 = 70.0;
const S: f32 = 1 / (std.math.tan(fov * 3.1415926535 / 90.0));
const matrix = [4][4]f32{
    .{S,  0,  0,  0},
    .{0,  S,  0,  0},
    .{0,  0, -(far / (far - near)),  -(far * near / (far - near))},
    .{0,  0, -1, 0},
};

fn update(delta: f32) void {
    draw.fillScreenWithRGBColor(100, 100, 100);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}", .{ 1 / delta, delta }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
    
    var mx = [_]f32{ 0.0, -0.5, 0.5, 0.5 };
    var my = [_]f32{ 0.5, -0.5, -0.5, 0.5 };
    var mz = [_]f32{-1.0, -1.0, -1.0, -0.5 };
    var mw = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    
    var mi = [_]u32{ 0, 1, 2, 0, 3, 1 };
    var mu = [_]f32{ 0.5, 0.0, 1.0, 0.5 };
    var mv = [_]f32{ 0.0, 1.0, 1.0, 0.5 };
    
    var mcolors = [_]draw.Color{
        draw.Color.c(1, 0, 0, 1),
        draw.Color.c(0, 1, 0, 1),
        draw.Color.c(0, 0, 1, 1),
        draw.Color.c(1, 0, 1, 1),
    };
    
    // NOTE(Samuel): Mesh Transformation
    
    if (draw.keyPressed(.d)) t_x += delta; 
    if (draw.keyPressed(.a)) t_x -= delta; 
    
    if (draw.keyPressed(.w)) t_y += delta; 
    if (draw.keyPressed(.s)) t_y -= delta; 
    
    if (draw.keyPressed(.e)) t_z += delta; 
    if (draw.keyPressed(.q)) t_z -= delta; 
    
    var mesh = draw.Mesh{
        .x = &mx,
        .y = &my,
        .z = &mz,
        .w = &mw,
        .i = &mi,
        .u = &mu,
        .v = &mv,
        .colors = &mcolors,
        .texture = potato,
    };
    
    var i: u32 = 0;
    while (i < mesh.x.len) : (i += 1) {
        mesh.z[i] += t_z;
        const new_x = matrix[0][0] * mesh.x[i] + t_x;
        const new_y = matrix[1][1] * mesh.y[i] + t_y;
        const new_z = matrix[2][2] * mesh.z[i] + matrix[2][3];
        mesh.w[i] = matrix[3][2] * mesh.z[i] + matrix[3][3];
        mesh.x[i] = new_x / mesh.w[i];
        mesh.y[i] = new_y / mesh.w[i];
        mesh.z[i] = new_z / mesh.w[i];
    }
    
    // TODO(Samuel): Cliping
    
    draw.rasterMesh(mesh);
}

var t_x: f32 = 0.0; 
var t_y: f32 = 0.0; 
var t_z: f32 = 0.0; 
