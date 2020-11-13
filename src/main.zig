// === Import libs ===
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const math = std.math;

const draw = @import("pixel_draw.zig");
usingnamespace draw.vector_math;
const Texture = draw.Texture;

// === Global Variables ===
var main_allocator: *Allocator = undefined;
var font: draw.BitmapFont = undefined;
var potato: Texture = undefined;
var bad_floor: Texture = undefined;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    main_allocator = &gpa.allocator;
    
    try draw.init(&gpa.allocator, 1280, 720, start, update);
    end();
}

var quad_mesh: draw.Mesh = undefined;
var palheta: draw.Texture = undefined;

fn start() void {
    font = .{
        .texture = draw.textureFromTgaData(main_allocator, @embedFile("../assets/font.tga")) catch unreachable,
        .font_size_x = 12,
        .font_size_y = 16,
        .character_spacing = 11,
    };
    potato = draw.textureFromTgaData(main_allocator, @embedFile("../assets/potato.tga")) catch unreachable;
    bad_floor = draw.textureFromTgaData(main_allocator, @embedFile("../assets/bad_floor.tga")) catch unreachable;
    
    cube_mesh.texture = potato;
    quad_mesh = draw.createQuadMesh(main_allocator, 21, 21, 10.5, 10.5, bad_floor, .Tile);
    
    for (quad_mesh.v) |*v| {
        v.pos = rotateVectorOnX(v.pos, 3.1415926535 * 0.5);
        v.pos.y -= 0.3;
    }
    
    sky = draw.meshFromObjData(main_allocator, @embedFile("../assets/SkySphere.obj"));
    clock = draw.meshFromObjData(main_allocator, @embedFile("../assets/GreatGeorge.obj"));
    terrain = draw.meshFromObjData(main_allocator, @embedFile("../assets/cenario.obj"));
    
    palheta = draw.textureFromTgaData(main_allocator, @embedFile("../assets/Palheta2.tga")) catch unreachable;
    sky.texture = draw.textureFromTgaData(main_allocator, @embedFile("../assets/sky.tga")) catch unreachable;
    
    for (clock.v) |*v| {
        v.pos.y -= 0.25;
    }
    
    for (sky.v) |*v| {
        v.pos = Vec3_mul_F(v.pos, 500);
    }
    
    clock.texture = palheta;
    terrain.texture = palheta;
    //quad_mesh.texture = palheta;
}

var clock: draw.Mesh = undefined;
var sky: draw.Mesh = undefined;
var terrain: draw.Mesh = undefined;

fn end() void {
    main_allocator.free(font.texture.raw);
    main_allocator.free(potato.raw);
    main_allocator.free(bad_floor.raw);
    main_allocator.free(quad_mesh.v);
    main_allocator.free(quad_mesh.i);
}

var print_buff: [512]u8 = undefined;


var cube_v = [_]Vertex {
    Vertex.c(Vec3.c(-0.5,  0.5,  0.5), Vec2.c(0, 1)),
    Vertex.c(Vec3.c( 0.5,  0.5,  0.5), Vec2.c(1, 1)),
    Vertex.c(Vec3.c(-0.5, -0.5,  0.5), Vec2.c(0, 0)),
    Vertex.c(Vec3.c( 0.5, -0.5,  0.5), Vec2.c(1, 0)),
    
    Vertex.c(Vec3.c(-0.5,  0.5, -0.5), Vec2.c(1, 1)),
    Vertex.c(Vec3.c( 0.5,  0.5, -0.5), Vec2.c(0, 1)),
    Vertex.c(Vec3.c(-0.5, -0.5, -0.5), Vec2.c(1, 0)),
    Vertex.c(Vec3.c( 0.5, -0.5, -0.5), Vec2.c(0, 0)),
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

var mov_speed: f32 = 2.0; 

fn update(delta: f32) void {
    draw.fillScreenWithRGBColor(50, 100, 150);
    
    
    // NOTE(Samuel): Mesh Transformation
    
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
    camera_delta_p = Vec3_mul_F(camera_delta_p, delta * mov_speed);
    
    cam.pos = Vec3_add(camera_delta_p, cam.pos);
    
    draw.drawMesh(clock, .Texture, cam);
    draw.drawMesh(terrain, .Texture, cam);
    draw.drawMesh(sky, .NoShadow, cam);
    
    //draw.drawMesh(quad_mesh, .Texture, cam);
    //draw.drawMesh(cube_mesh, .Texture, cam);
    
    { // Show fps
        const fpst = std.fmt.bufPrint(&print_buff, "{d:0.4}/{d:0.4}/{d}", .{ 1 / delta, delta, mov_speed }) catch unreachable;
        draw.drawBitmapFont(fpst, 20, 20, 1, 1, font);
    }
}

var cam: draw.Camera3D = .{.pos = .{.z = 2.0}, .far = 1000};


