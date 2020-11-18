// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

const draw = @import("pixel_draw.zig");
usingnamespace draw.vector_math;
const Texture = draw.Texture;

// ========== Global Variables =============
var main_allocator: *Allocator = undefined;
var font: draw.BitmapFont = undefined;
var potato: Texture = undefined;
var earth_mesh: draw.Mesh = undefined;
var mundi: draw.Texture = undefined;
// =========================================

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    main_allocator = &gpa.allocator;
    
    try draw.init(&gpa.allocator, 1280, 720, start, update);
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
    mundi = draw.textureFromTgaData(main_allocator, @embedFile("../assets/mundi.tga")) catch unreachable;
    
    earth_mesh = draw.createQuadMesh(main_allocator, 32, 32, 0, 0, mundi, .Strech);
    for (earth_mesh.v) |*v| {
        v.pos.x = (v.pos.x / 32.0) * -3.141592 * 2;
        v.pos.y = (v.pos.y / 32.0) * -3.141592;
        v.pos = sphericalToCartesian(10.0, v.pos.y, v.pos.x);
        v.pos = rotateVectorOnX(v.pos, -3.1415926535 * 0.5);
    }
}

fn end() void {
    main_allocator.free(font.texture.raw);
    main_allocator.free(potato.raw);
    main_allocator.free(mundi.raw);
    main_allocator.free(earth_mesh.v);
    main_allocator.free(earth_mesh.i);
}

var cam: draw.Camera3D = .{ .pos = .{ .z = 2.0 }, .far = 100000 };
var mov_speed: f32 = 2.0;

fn update(delta: f32) void {
    
    if (draw.keyPressed(.up)) cam.rotation.x += delta * 2;
    if (draw.keyPressed(.down)) cam.rotation.x -= delta * 2;
    if (draw.keyPressed(.right)) cam.rotation.y += delta * 2;
    if (draw.keyPressed(.left)) cam.rotation.y -= delta * 2;
    
    if (draw.keyPressed(._1)) cam.pos.y += delta * mov_speed;
    if (draw.keyPressed(._2)) cam.pos.y -= delta * mov_speed;
    
    if (draw.keyDown(._0)) mov_speed += 2.0;
    if (draw.keyDown(._9)) mov_speed -= 2.0;
    
    var camera_forward = eulerAnglesToDirVector(cam.rotation);
    camera_forward.y = 0;
    var camera_right = eulerAnglesToDirVector(Vec3.c(cam.rotation.x, cam.rotation.y - 3.1415926535 * 0.5, cam.rotation.z));
    camera_right.y = 0;
    
    const input_z = draw.keyStrengh(.s) - draw.keyStrengh(.w);
    const input_x = draw.keyStrengh(.d) - draw.keyStrengh(.a);
    
    camera_forward = Vec3_mul_F(camera_forward, input_z);
    camera_right = Vec3_mul_F(camera_right, input_x);
    
    var camera_delta_p = Vec3_add(camera_forward, camera_right);
    camera_delta_p = Vec3_normalize(camera_delta_p);
    camera_delta_p = Vec3_mul_F(camera_delta_p, delta * mov_speed);
    
    cam.pos = Vec3_add(camera_delta_p, cam.pos);
    
    draw.gb.fillScreenWithRGBColor(0, 0, 0);
    draw.gb.drawMesh(earth_mesh, .Texture, cam);
    draw.gb.drawBitmapFontFmt("{d:0.4}/{d:0.4}/{d}", .{ 1 / delta, delta, mov_speed }, 20, 20, 1, 1, font);
}

