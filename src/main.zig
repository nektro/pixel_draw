// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

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
    quad_mesh = draw.createQuadMesh(main_allocator, 21, 21, 10.5, 10.5, potato, .Tile);
    
    for (quad_mesh.v) |*v| {
        v.pos = rotateVectorOnX(v.pos, 3.1415926535 * 0.5);
        v.pos.y -= 0.5;
    }
}

fn end() void {
    main_allocator.free(font.texture.raw);
    main_allocator.free(potato.raw);
}

var print_buff: [512]u8 = undefined;


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
    draw.fillScreenWithRGBColor(50, 100, 150);
    
    // NOTE(Samuel): Mesh Transformation
    
    if (draw.keyPressed(.up)) cam.rotation.x += delta * 2; 
    if (draw.keyPressed(.down)) cam.rotation.x -= delta * 2;
    if (draw.keyPressed(.right)) cam.rotation.y += delta * 2; 
    if (draw.keyPressed(.left)) cam.rotation.y -= delta * 2;
    
    var camera_forward = eulerAnglesToDirVector(cam.rotation);
    camera_forward.y = 0;
    var camera_right = eulerAnglesToDirVector(Vec3.c(cam.rotation.x,
                                                     cam.rotation.y - 3.1415926535 * 0.5,
                                                     cam.rotation.z));
    camera_right.y = 0;
    
    const input_z = draw.keyStrengh(.s) - draw.keyStrengh(.w);
    const input_x = draw.keyStrengh(.d) - draw.keyStrengh(.a);
    
    camera_forward = Vec3_mul_F(camera_forward, input_z);
    camera_right = Vec3_mul_F(camera_right, input_x);
    
    var camera_delta_p = Vec3_add(camera_forward, camera_right);
    camera_delta_p = Vec3_normalize(camera_delta_p);
    camera_delta_p = Vec3_mul_F(camera_delta_p, delta * 3);
    
    cam.pos = Vec3_add(camera_delta_p, cam.pos);
    
    draw.drawMesh(quad_mesh, .Texture, cam);
    draw.drawMesh(cube_mesh, .Texture, cam);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}", .{ 1 / delta, delta }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
}

var cam: draw.Camera3D = .{.pos = .{.z = 2.0}};


