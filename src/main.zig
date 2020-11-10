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
var matrix = [4][4]f32{
    .{-S,  0,  0,  0},
    .{0,  -S,  0,  0},
    .{0,  0, -(far / (far - near)),  -(far * near / (far - near))},
    .{0,  0, -1, 0},
};

fn update(delta: f32) void {
    // Update perspective matrix with the aspect ratio
    matrix[0][0] = -S * (@intToFloat(f32, draw.win_height) / @intToFloat(f32, draw.win_width));
    
    draw.fillScreenWithRGBColor(50, 100, 150);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}", .{ 1 / delta, delta }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
    
    var mx = [_]f32{-0.5, 0.5, -0.5,  0.5, -0.5,  0.5, -0.5,  0.5};
    var my = [_]f32{ 0.5, 0.5, -0.5, -0.5,  0.5,  0.5, -0.5, -0.5};
    var mz = [_]f32{ 0.5, 0.5,  0.5,  0.5, -0.5, -0.5, -0.5, -0.5};
    
    var mi = [_]u32{
        0, 2, 3,
        0, 3, 1,
        1, 3, 7,
        1, 7, 5,
        4, 0, 1,
        4, 1, 5,
        4, 6, 2,
        4, 2, 0,
        6, 3, 2,
        6, 7, 3,
        5, 7, 6,
        5, 6, 4,
    };
    var mu = [_]f32{ 0.5, 0.0, 1.0, 0.5 };
    var mv = [_]f32{ 0.0, 1.0, 1.0, 0.5 };
    
    var mcolors = [_]draw.Color{
        draw.Color.c(0.5, 0.5, 0.5, 1),
        draw.Color.c(0, 0, 1, 1),
        draw.Color.c(0, 1, 0, 1),
        draw.Color.c(0, 1, 1, 1),
        draw.Color.c(1, 0, 0, 1),
        draw.Color.c(1, 0, 1, 1),
        draw.Color.c(1, 1, 0, 1),
        draw.Color.c(1, 1, 1, 1),
    };
    
    // NOTE(Samuel): Mesh Transformation
    
    if (draw.keyPressed(.d)) t_x += delta; 
    if (draw.keyPressed(.a)) t_x -= delta; 
    
    if (draw.keyPressed(.w)) t_y += delta; 
    if (draw.keyPressed(.s)) t_y -= delta; 
    
    if (draw.keyPressed(.up)) t_z -= delta; 
    if (draw.keyPressed(.down)) t_z += delta;
    
    if (draw.keyPressed(.right)) theta += delta;
    if (draw.keyPressed(.left)) theta -= delta;
    
    var mesh = draw.Mesh{
        .x = &mx,
        .y = &my,
        .z = &mz,
        .i = &mi,
        .u = &mu,
        .v = &mv,
        .colors = &mcolors,
        .texture = potato,
    };
    
    var i: u32 = 0;
    while (i < mesh.x.len) : (i += 1) {
        // Rotate in Y
        {
            const new_x = mesh.x[i] * @cos(theta) + mesh.z[i] * @sin(theta);
            const new_z = -mesh.x[i] * @sin(theta) + mesh.z[i] * @cos(theta);
            mesh.x[i] = new_x;
            mesh.z[i] = new_z;
        }
    }
    
    const cam = draw.Camera3D{
        .x = t_x,
        .y = t_y,
        .z = t_z,
    };
    
    draw.drawMesh(mesh, .Faces, matrix, cam);
    draw.drawMesh(mesh, .Lines, matrix, cam);
    draw.drawMesh(mesh, .Points, matrix, cam);
}

var t_x: f32 = 0.0; 
var t_y: f32 = 0.0; 
var t_z: f32 = 2.0;
var theta: f32 = 0.0;
