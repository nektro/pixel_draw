// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

usingnamespace @import("util.zig");
usingnamespace @import("vector_math.zig");
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

var quad_mesh: draw.Mesh = undefined;

fn start() void {
    font = .{
        .texture = draw.textureFromTgaData(main_allocator, @embedFile("../assets/font.tga")) catch unreachable,
        .font_size_x = 12,
        .font_size_y = 16,
        .character_spacing = 11,
    };
    potato = draw.textureFromTgaData(main_allocator, @embedFile("../assets/potato.tga")) catch unreachable;
    
    cube_mesh.texture = potato;
    quad_mesh = draw.createQuadMesh(main_allocator, 20, 20, 10, 10, potato);
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

var cube_v = [_]Vertex {
    Vertex.c(Vec3.c(-0.5,  0.5,  0.5), Color.c(0, 0, 0, 1), Vec2.c(0, 1)),
    Vertex.c(Vec3.c( 0.5,  0.5,  0.5), Color.c(0, 0, 1, 1), Vec2.c(1, 1)),
    Vertex.c(Vec3.c(-0.5, -0.5,  0.5), Color.c(0, 1, 0, 1), Vec2.c(0, 0)),
    Vertex.c(Vec3.c( 0.5, -0.5,  0.5), Color.c(0, 1, 1, 1), Vec2.c(1, 0)),
    
    Vertex.c(Vec3.c(-0.5,  0.5, -0.5), Color.c(1, 0, 0, 1), Vec2.c(1, 1)),
    Vertex.c(Vec3.c( 0.5,  0.5, -0.5), Color.c(1, 0, 1, 1), Vec2.c(0, 1)),
    Vertex.c(Vec3.c(-0.5, -0.5, -0.5), Color.c(1, 1, 0, 1), Vec2.c(1, 0)),
    Vertex.c(Vec3.c( 0.5, -0.5, -0.5), Color.c(1, 1, 1, 1), Vec2.c(0, 0)),
};

var cube_i = [_]u32{
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

var cube_mesh = draw.Mesh{
    .v = &cube_v,
    .i = &cube_i,
    .texture = undefined,
};


fn update(delta: f32) void {
    // Update perspective matrix with the aspect ratio
    matrix[0][0] = -S * (@intToFloat(f32, draw.win_height) / @intToFloat(f32, draw.win_width));
    
    draw.fillScreenWithRGBColor(50, 100, 150);
    
    // NOTE(Samuel): Mesh Transformation
    
    if (draw.keyPressed(.d)) cam.pos.x += delta * 2; 
    if (draw.keyPressed(.a)) cam.pos.x -= delta * 2; 
    
    if (draw.keyPressed(.w)) cam.pos.y += delta * 2; 
    if (draw.keyPressed(.s)) cam.pos.y -= delta * 2; 
    
    if (draw.keyPressed(.up)) cam.pos.z -= delta * 2; 
    if (draw.keyPressed(.down)) cam.pos.z += delta * 2;
    
    var theta: f32 = 0.0;
    if (draw.keyPressed(.right)) theta = delta;
    if (draw.keyPressed(.left)) theta = -delta;
    
    var i: u32 = 0;
    while (i < quad_mesh.v.len) : (i += 1) {
        // Rotate in Y
        const new_x = quad_mesh.v[i].pos.x * @cos(theta) + quad_mesh.v[i].pos.z * @sin(theta);
        const new_z = -quad_mesh.v[i].pos.x * @sin(theta) + quad_mesh.v[i].pos.z * @cos(theta);
        quad_mesh.v[i].pos.x = new_x;
        quad_mesh.v[i].pos.z = new_z;
    }
    i = 0;
    while (i < cube_mesh.v.len) : (i += 1) {
        // Rotate in Y
        const new_x = cube_mesh.v[i].pos.x * @cos(theta) + cube_mesh.v[i].pos.z * @sin(theta);
        const new_z = -cube_mesh.v[i].pos.x * @sin(theta) + cube_mesh.v[i].pos.z * @cos(theta);
        cube_mesh.v[i].pos.x = new_x;
        cube_mesh.v[i].pos.z = new_z;
    }
    
    draw.drawMesh(quad_mesh, .Texture, matrix, cam);
    //draw.drawMesh(quad_mesh, .Lines, matrix, cam);
    
    draw.drawMesh(cube_mesh, .Texture, matrix, cam);
    //draw.drawMesh(cube_mesh, .Lines, matrix, cam);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}", .{ 1 / delta, delta }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
}

var cam: draw.Camera3D = .{.pos = .{.z = 2.0}};


