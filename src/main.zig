// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

const draw = @import("pixel_draw.zig");
usingnamespace draw.vector_math;
const Texture = draw.Texture;

const voxel = @import("voxel.zig");

// ========== Global Variables =============
var main_allocator: *Allocator = undefined;
var font: draw.BitmapFont = undefined;
var potato: Texture = undefined;
var cube_mesh: draw.Mesh = undefined;
var test_chunk: voxel.Chunk = undefined;
// =========================================

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer _ = gpa.deinit(); // NOTE(Samuel): Dont want leak test
    
    main_allocator = &gpa.allocator;
    
    try draw.init(&gpa.allocator, 1280, 720, start, update);
    end();
}

fn start() void {
    voxel.initBlockList(main_allocator) catch @panic("Unable to init block list");
    test_chunk = voxel.Chunk.init();
    
    font = .{
        .texture = draw.textureFromTgaData(main_allocator, @embedFile("../assets/font.tga")) catch unreachable,
        .font_size_x = 12,
        .font_size_y = 16,
        .character_spacing = 11,
    };
    
    potato = draw.textureFromTgaData(main_allocator, @embedFile("../assets/potato.tga")) catch unreachable;
    
    cube_mesh = draw.cubeMesh(main_allocator);
    cube_mesh.texture = potato;
}

fn end() void {
    // NOTE(Samuel): Let the OS handle this
    //main_allocator.free(font.texture.raw);
    //main_allocator.free(potato.raw);
    //main_allocator.free(cube_mesh.v);
    //main_allocator.free(cube_mesh.i);
}

var cam: draw.Camera3D = .{ .pos = .{ .z = 20.0 }, .far = 100000 };
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
    
    draw.gb.fillScreenWithRGBColor(50, 50, 200);
    {
        for (test_chunk.block_data) |*it, i| {
            if (it.* != 0) {
                var x: u32 = 0;
                var y: u32 = 0;
                var z: u32 = 0;
                
                voxel.Chunk.posFromI(i, &x, &y, &z);
                const transform = Transform{
                    .position = .{
                        .x = @intToFloat(f32, x),
                        .y = @intToFloat(f32, y),
                        .z = @intToFloat(f32, z),
                    },
                };
                draw.gb.drawMesh(cube_mesh, .Texture, cam, transform);
            }
        }
    }
    draw.gb.drawBitmapFontFmt("{d:0.4}/{d:0.4}/{d}", .{ 1 / delta, delta, mov_speed }, 20, 20, 1, 1, font);
    
}

