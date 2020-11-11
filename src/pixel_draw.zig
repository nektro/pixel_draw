const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

usingnamespace if (@import("builtin").os.tag == .windows)
@import("win32_plataform.zig")
else
@import("xlib_plataform.zig");

usingnamespace @import("vector_math.zig");

// ===== Input =====
const MouseButtons = enum(u32) {
    zero = 0,
    left = 1,
    middle = 2,
    right = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
};
pub fn mouseButtonDown(button: MouseButtons) bool {
    return mouse_buttons_down[@enumToInt(button)];
}
pub fn mouseButtonUp(button: MouseButtons) bool {
    return mouse_buttons_up[@enumToInt(button)];
}
pub fn mouseButtonPressed(button: MouseButtons) bool {
    return mouse_buttons_pressed[@enumToInt(button)];
}

const Keys = enum(u32) {
    q = 0,
    w = 1,
    e = 2,
    r = 3,
    a = 4,
    s = 5,
    d = 6,
    _1 = 7,
    _2 = 8,
    _3 = 9,
    _4 = 10,
    _5 = 11,
    _6 = 12,
    _7 = 13,
    _8 = 14,
    _9 = 15,
    _0 = 16,
    up = 17,
    down = 18,
    left = 19,
    right = 20,
};

pub inline fn keyDown(key: Keys) bool {
    return keys_down[@enumToInt(key)];
}
pub inline fn keyUp(key: Keys) bool {
    return keys_up[@enumToInt(key)];
}

pub inline fn keyPressed(key: Keys) bool {
    return keys_pressed[@enumToInt(key)];
}

pub const init = plataformInit;

const BmpHeader = packed struct {
    file_type: u16,
    file_size: u32,
    reserved1: u16,
    reserved2: u16,
    bitmap_offset: u32,
    
    size: u32,
    width: i32,
    height: i32,
    planes: u16,
    bits_per_pixel: u16,
    
    compression: u32,
    size_of_bitmap: u32,
    horz_resolution: i32,
    vert_resolution: i32,
    colors_used: u32,
    colors_important: u32,
};

pub const Texture = struct {
    width: u32,
    height: u32,
    raw: []u8,
};

// Simple texture mapping function, no filter
pub inline fn textureMap(u: f32, v: f32, tex: Texture) [4]f32 {
    const tex_u = @floatToInt(u32, (@intToFloat(f32, tex.width) * u)) % tex.width;
    const tex_v = @floatToInt(u32, (@intToFloat(f32, tex.height) * v)) % tex.height;
    
    const tex_pos = (tex_u + tex_v * tex.height) * 4;
    const pixel = tex.raw[tex_pos..][0..4];
    return [4]f32 {
        @intToFloat(f32, pixel[0]) / 255.0,
        @intToFloat(f32, pixel[1]) / 255.0,
        @intToFloat(f32, pixel[2]) / 255.0,
        @intToFloat(f32, pixel[3]) / 255.0,
    };
}

pub fn colorFromRgba(r: u8, g: u8, b: u8, a: u8) Color {
    return Color{
        .r = @intToFloat(f32, r) / 255.0,
        .g = @intToFloat(f32, g) / 255.0,
        .b = @intToFloat(f32, b) / 255.0,
        .a = @intToFloat(f32, a) / 255.0,
    };
}

/// This function is problably very unsafe
/// it will change later
pub fn textureFromBmpData(bmp_data: []const u8) !Texture {
    const header: *const BmpHeader = @ptrCast(
                                              *const BmpHeader,
                                              bmp_data[0..@sizeOf(BmpHeader)],
                                              );
    
    if (header.file_type != 0x4d42) return error.NotBmpFile;
    if (header.compression != 3) return error.CompressedFile;
    if (header.bits_per_pixel != 32) return error.InvalidBitsPerPixel;
    
    var result_image: Texture = undefined;
    result_image.width = @intCast(u32, header.width);
    result_image.height = @intCast(u32, header.height);
    result_image.pitch = 0;
    result_image.raw = bmp_data[header.bitmap_offset..];
    
    return result_image;
}

pub inline fn loadBMP(path: []const u8) !Texture {
    const data = try std.fs.cwd().readFileAlloc(std.heap.c_allocator, path, 1024 * 1024 * 128);
    return textureFromBmpData(data);
}

const TGAHeader = packed struct {
    id_lenth: u8,
    colour_map_type: u8,
    data_type_code: u8,
    color_map_origin: u16,
    color_map_length: u16,
    color_map_depth: u8,
    x_origin: u16,
    y_origin: u16,
    width: u16,
    height: u16,
    bits_per_pixel: u8,
    image_descriptor: u8,
};

pub fn textureFromTgaData(al: *Allocator, file_data: []const u8) !Texture {
    const header = @ptrCast(*const TGAHeader, &file_data[0]);
    
    // Assert that the image is Runlength encoded RGB
    if (header.data_type_code != 10) {
        return error.InvalidTGAFormat;
    }
    
    if (header.bits_per_pixel != 32) {
        return error.InvalidBitsPerPixel;
    }
    
    var data = file_data[(@sizeOf(TGAHeader) + header.id_lenth)..][0..(file_data.len - 26)];
    
    var result = Texture{
        .width = header.width,
        .height = header.height,
        .raw = undefined,
    };
    
    var result_data = try al.alloc(u8, @intCast(u32, header.width) * @intCast(u32, header.height) * 4);
    for (result_data) |*rd| rd.* = 0;
    errdefer al.free(result.raw);
    
    var index: usize = 0;
    var texture_index: usize = 0;
    outer_loop: while (index < data.len) {
        const pb = data[index];
        index += 1;
        const packet_len = pb & 0x7f;
        
        if ((pb & 0x80) == 0x00) { // raw packet
            var i: usize = 0;
            while (i <= packet_len) : (i += 1) {
                const alpha = data[index + 3];
                const multiplier = @boolToInt(alpha != 0);
                result_data[texture_index] = data[index] * multiplier;
                result_data[texture_index + 1] = data[index + 1] * multiplier;
                result_data[texture_index + 2] = data[index + 2] * multiplier;
                result_data[texture_index + 3] = alpha;
                texture_index += 4;
                if (texture_index >= result_data.len - 3) break :outer_loop;
                index += 4;
            }
        } else { // rl packet
            var i: usize = 0;
            while (i <= packet_len) : (i += 1) {
                const alpha = data[index + 3];
                const multiplier = @boolToInt(alpha != 0);
                result_data[texture_index] = data[index] * multiplier;
                result_data[texture_index + 1] = data[index + 1] * multiplier;
                result_data[texture_index + 2] = data[index + 2] * multiplier;
                result_data[texture_index + 3] = alpha;
                texture_index += 4;
                if (texture_index >= result_data.len - 3) break :outer_loop;
            }
            index += 4;
        }
    }
    
    result.raw = result_data;
    return result;
}
/// A simple function that loads a simple Runlength encoded RGBA TGA image
pub fn loadTGA(al: *Allocator, path: []const u8) !Texture {
    const file_data = try std.fs.cwd().readFileAlloc(al, path, 1024 * 1024 * 128);
    defer al.free(file_data);
    
    return try textureFromTgaData(al, file_data);
}

test "TGA_Read" {
    assert(@sizeOf(TGAHeader) == 18);
    _ = try loadTGA("potato.tga");
}

pub inline fn putPixel(xi: i32, yi: i32, color: Color) void {
    if (xi > win_width - 1) return;
    if (yi > win_height - 1) return;
    if (xi < 0) return;
    if (yi < 0) return;
    
    const x = @intCast(u32, xi);
    const y = @intCast(u32, yi);
    
    const pixel = screen_buffer[(x + y * win_width) * 4 ..][0..3];
    // TODO: Alpha blending
    if (color.a > 0.999) {
        pixel[0] = @floatToInt(u8, color.b * 255);
        pixel[1] = @floatToInt(u8, color.g * 255);
        pixel[2] = @floatToInt(u8, color.r * 255);
    }
}

pub inline fn putPixelRGBA(x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
    if (x > win_width - 1) return;
    if (y > win_height - 1) return;
    if (x < 0) return;
    if (y < 0) return;
    
    const pixel = screen_buffer[(x + y * win_width) * 4 ..][0..3];
    // TODO: Alpha blending
    if (a > 0) {
        pixel[0] = r;
        pixel[1] = g;
        pixel[2] = b;
    }
}

pub fn fillCircle(x: i32, y: i32, r: u32, color: Color) void {
    var v: i32 = -@intCast(i32, r);
    while (v <= r) : (v += 1) {
        var u: i32 = -@intCast(i32, r);
        while (u <= r) : (u += 1) {
            if (u * u + v * v < (r * r)) {
                putPixel(
                         x + u,
                         y + v,
                         color,
                         );
            }
        }
    }
}

pub const BitmapFont = struct {
    texture: Texture,
    font_size_x: u32,
    font_size_y: u32,
    character_spacing: u32,
};

pub fn drawBitmapFont(text: []const u8, x: u32, y: u32,
                      scale_x: u32, scale_y: u32,
                      font: BitmapFont) void
{
    for (text) |t, i| {
        const char_index: u32 = t;
        const fx = char_index % 16 * font.font_size_x;
        const fy = char_index / 16 * font.font_size_y;
        
        drawBitmapChar(
                       t,
                       x + @intCast(u32, i) * scale_x * font.character_spacing,
                       y,
                       scale_x,
                       scale_y,
                       font,
                       );
    }
}

// TODO(Samuel): Optimize this function
pub fn drawBitmapChar(char: u8, x: u32, y: u32,
                      scale_x: u32, scale_y: u32,
                      font: BitmapFont) void
{
    const fx = char % 16 * font.font_size_x;
    const fy = char / 16 * font.font_size_y;
    
    var yi: u32 = 0;
    while (yi < font.font_size_y) : (yi += 1) {
        var xi: u32 = 0;
        while (xi < font.font_size_x) : (xi += 1) {
            const tex_pos = ((fx + xi) +
                             (fy + yi) * font.texture.width) * 4;
            const color = font.texture.raw[tex_pos..][0..4];
            
            var sy: u32 = 0;
            while (sy < scale_y) : (sy += 1) {
                var sx: u32 = 0;
                while (sx < scale_x) : (sx += 1) {
                    putPixelRGBA(x + xi * scale_x + sx,
                                 y + yi * scale_y + sy,
                                 color[0], color[1],
                                 color[2], color[3]);
                }
            }
        }
    }
}

/// draw a filled rectangle
pub fn fillRect(x: i32, y: i32, w: u32, h: u32, color: Color) void {
    // Clamp values
    const max_x = @intCast(i32, win_width);
    const max_y = @intCast(i32, win_height);
    
    const x1 = std.math.clamp(x, 0, max_x);
    const y1 = std.math.clamp(y, 0, max_y);
    
    const sx2 = @intCast(i32, w) + x;
    const sy2 = @intCast(i32, h) + y;
    const x2 = std.math.clamp(sx2, 0, max_x);
    const y2 = std.math.clamp(sy2, 0, max_y);
    
    var y_i: i32 = y1;
    while (y_i < y2) : (y_i += 1) {
        var x_i: i32 = x1;
        while (x_i < x2) : (x_i += 1) {
            putPixel(x_i, y_i, color);
        }
    }
}

pub fn drawTexture(x: i32, y: i32, w: u32, h: u32, tex: Texture) void {
    const max_x = @intCast(i32, win_width);
    const max_y = @intCast(i32, win_height);
    
    const x1 = @intCast(u32, std.math.clamp(x, 0, max_x));
    const y1 = @intCast(u32, std.math.clamp(y, 0, max_y));
    
    const sx2 = @intCast(i32, w) + x;
    const sy2 = @intCast(i32, h) + y;
    const x2 = @intCast(u32, std.math.clamp(sx2, 0, max_x));
    const y2 = @intCast(u32, std.math.clamp(sy2, 0, max_y));
    
    var texture_y: u32 = @intCast(u32, @intCast(i32, y1) - y);
    var screen_y: u32 = y1;
    while (screen_y < y2) : (screen_y += 1) {
        var texture_x: u32 = @intCast(u32, @intCast(i32, x1) - x);
        var screen_x: u32 = x1;
        while (screen_x < x2) : (screen_x += 1) {
            // get pointer to pixel on the screen
            const buffer_i = 4 * (screen_x + screen_y * win_width);
            const pixel = screen_buffer[buffer_i..];
            
            // get pointer to pixel on texture
            const tex_pixel_pos = 4 * (((texture_x * tex.width) / w) +
                                       ((texture_y * tex.height) / h) * tex.width);
            const tex_pixel = tex.raw[tex_pixel_pos..];
            
            @memcpy(pixel.ptr, tex_pixel.ptr, 4);
            
            texture_x += 1;
        }
        texture_y += 1;
    }
}

// Blit texture on screen, does not change the size of the texture
pub fn blitTexture(x: i32, y: i32, tex: Texture) void {
    // Clamp values
    const max_x = @intCast(i32, win_width);
    const max_y = @intCast(i32, win_height);
    
    const x1 = @intCast(u32, std.math.clamp(x, 0, max_x));
    const y1 = @intCast(u32, std.math.clamp(y, 0, max_y));
    
    const sx2 = @intCast(i32, tex.width) + x;
    const sy2 = @intCast(i32, tex.height) + y;
    const x2 = @intCast(u32, std.math.clamp(sx2, 0, max_x));
    const y2 = @intCast(u32, std.math.clamp(sy2, 0, max_y));
    
    var texture_y: u32 = if (y < y1) @intCast(u32, @intCast(i32, y1) - y) else 0;
    var screen_y: u32 = y1;
    
    const texture_x: u32 = if (x < x1 and x2 > 0) @intCast(u32, @intCast(i32, x1) - x) else 0;
    while (screen_y < y2) : (screen_y += 1) {
        // get pointer to pixel on texture
        const tex_pixel_pos = 4 * (texture_x + texture_y * tex.width);
        const tex_pixel = tex.raw[tex_pixel_pos..];
        
        // get pointer to pixel on screen
        const buffer_i = 4 * (x1 + screen_y * win_width);
        const pixel = screen_buffer[buffer_i..];
        
        @memcpy(pixel.ptr, tex_pixel.ptr, 4 * (x2 - x1));
        
        texture_y += 1;
    }
}

/// draw a hollow rectangle
pub fn drawRect(x: i32, y: i32, w: u32, h: u32, color: Color) void {
    const width = @intCast(i32, std.math.clamp(w, 0, win_width)) - x;
    const height = @intCast(i32, std.math.clamp(h, 0, win_height)) - y;
    
    const max_x = @intCast(i32, win_width);
    const max_y = @intCast(i32, win_height);
    
    const x1 = std.math.clamp(x, 0, max_x);
    const y1 = std.math.clamp(y, 0, max_y);
    
    const sx2 = @intCast(i32, w) + x;
    const sy2 = @intCast(i32, h) + y;
    
    const x2 = std.math.clamp(sx2, 0, max_x);
    const y2 = std.math.clamp(sy2, 0, max_y);
    
    if (x2 == 0 or y2 == 0) return;
    
    var xi: i32 = x1;
    while (xi < x2) : (xi += 1) {
        putPixel(xi, y1, color);
        putPixel(xi, y2 - 1, color);
    }
    
    var yi: i32 = y1;
    while (yi < y2) : (yi += 1) {
        putPixel(x1, yi, color);
        putPixel(x2 - 1, yi, color);
    }
}

pub fn drawLine(xa: i32, ya: i32, xb: i32, yb: i32, color: Color) void {
    const xr = std.math.max(xa, xb);
    const xl = std.math.min(xa, xb);
    
    const yu = std.math.min(ya, yb);
    const yd = std.math.max(ya, yb);
    
    const x_dist = xr - xl;
    const y_dist = yd - yu;
    
    if (x_dist < y_dist) {
        var y = yu;
        var dx = @intToFloat(f32, x_dist) / @intToFloat(f32, y_dist);  
        
        var x: f32 = 0.0;
        if (ya == yu) {
            x = @intToFloat(f32, xa);
            if (xa == xr) dx = -dx;
        } else {
            x = @intToFloat(f32, xb);
            if (xb == xr) dx = -dx;
        }
        
        while (y <= yd) : (y += 1) {
            putPixel(@floatToInt(i32, x), y, color);
            x += dx;
        }
    } else {
        var x = xl;
        var dy = @intToFloat(f32, y_dist) / @intToFloat(f32, x_dist);  
        
        var y: f32 = 0.0;
        if (xa == xl) {
            y = @intToFloat(f32, ya);
            if (ya == yd) dy = -dy;
        } else {
            y = @intToFloat(f32, yb);
            if (yb == yd) dy = -dy;
        }
        
        while (x <= xr) : (x += 1) {
            putPixel(x, @floatToInt(i32, y), color);
            y += dy;
        }
    }
}

pub fn drawLineWidth(xa: i32, ya: i32, xb: i32, yb: i32,
                     color: Color, line_width: u32) void
{
    if (line_width == 1) {
        drawLine(xa, ya, xb, yb, color);
        return;
    }
    
    const xr = std.math.max(xa, xb);
    const xl = std.math.min(xa, xb);
    
    const yu = std.math.min(ya, yb);
    const yd = std.math.max(ya, yb);
    
    const x_dist = xr - xl;
    const y_dist = yd - yu;
    
    if (x_dist < y_dist) {
        var y = yu;
        var dx = @intToFloat(f32, x_dist) / @intToFloat(f32, y_dist);  
        
        var x: f32 = 0.0;
        if (ya == yu) {
            x = @intToFloat(f32, xa);
            if (xa == xr) dx = -dx;
        } else {
            x = @intToFloat(f32, xb);
            if (xb == xr) dx = -dx;
        }
        
        while (y <= yd) : (y += 1) {
            fillCircle(@floatToInt(i32, x), y, line_width / 2, color);
            x += dx;
        }
    } else {
        var x = xl;
        var dy = @intToFloat(f32, y_dist) / @intToFloat(f32, x_dist);  
        
        var y: f32 = 0.0;
        if (xa == xl) {
            y = @intToFloat(f32, ya);
            if (ya == yd) dy = -dy;
        } else {
            y = @intToFloat(f32, yb);
            if (yb == yd) dy = -dy;
        }
        
        while (x <= xr) : (x += 1) {
            fillCircle(x, @floatToInt(i32, y), line_width / 2, color);
            y += dy;
        }
    }
}

pub fn fillScreenWithRGBColor(r: u8, g: u8, b: u8) void {
    var index: usize = 0;
    while (index < screen_buffer.len) : (index += 4) {
        screen_buffer[index] = b;
        screen_buffer[index + 1] = g;
        screen_buffer[index + 2] = r;
    }
}

pub inline fn i32Abs(n: i32) i32 {
    return n * (-1 + 2 * @intCast(i32, @boolToInt(n > 0)));
}

pub inline fn f32Frac(n: f32) f32 {
    return n - @trunc(n);
}

inline fn edgeFunction(xa: f32, ya: f32, xb: f32, yb: f32, xc: f32, yc: f32) f32 {
    return (xc - xa) * (yb - ya) - (yc - ya) * (xb - xa);
}

inline fn edgeFunctionI(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32) i32 {
    return (xc - xa) * (yb - ya) - (yc - ya) * (xb - xa);
}

pub fn fillTriangle(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32, color: Color) void {
    const x_left  = math.min(math.min(xa, xb), math.max(xc, 0));
    const x_right = math.max(math.max(xa, xb), math.min(xc, @intCast(i32, win_width)));
    const y_up    = math.min(math.min(ya, yb), math.max(yc, 0));
    const y_down  = math.max(math.max(ya, yb), math.min(yc, @intCast(i32, win_height)));
    
    var y: i32 = y_up;
    while (y < y_down) : (y += 1) {
        var x: i32 = x_left;
        while (x < x_right) : (x += 1) {
            const w0 = edgeFunctionI(xb, yb, xc, yc, x, y);
            const w1 = edgeFunctionI(xc, yc, xa, ya, x, y);
            const w2 = edgeFunctionI(xa, ya, xb, yb, x, y);
            
            if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                putPixel(x, y, color);
            }
        }
    }
}

pub inline fn drawTriangle(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32,
                           color: Color, line_width: u32) void
{
    drawLineWidth(xa, ya, xb, yb, color, line_width);
    drawLineWidth(xb, yb, xc, yc, color, line_width);
    drawLineWidth(xc, yc, xa, ya, color, line_width);
}

// ==== 3d struff ====

pub const Mesh = struct {
    v: []Vertex,
    i: []u32,
    texture: Texture,
};

const RasterMode = enum {
    Points,
    Lines,
    Faces,
};

pub const Camera3D = struct {
    pos: Vec3 = .{},
};

pub const ClipTriangleReturn = struct {
    triangle0: [3]Vertex,
    triangle1: [3]Vertex,
    count: u32 = 0,
};

pub fn clipTriangle(triangle: [3]Vertex, plane: Plane) ClipTriangleReturn {
    
    var result = ClipTriangleReturn {
        .triangle0 = triangle,
        .triangle1 = triangle,
        .count = 1,
    };
    
    // Count outside of the plane
    var out_count: u32 = 0;
    
    const t0_out = blk: {
        const plane_origin = Vec3_mul_F(plane.n, -plane.d);
        const d = Vec3_dot(plane.n, Vec3_sub(triangle[0].pos, plane_origin));
        if (d < 0.0) {
            out_count += 1;
            break :blk true;
        }
        break :blk false;
    };
    
    const t1_out = blk: {
        const plane_origin = Vec3_mul_F(plane.n, -plane.d);
        const d = Vec3_dot(plane.n, Vec3_sub(triangle[1].pos, plane_origin));
        if (d < 0.0) {
            out_count += 1;
            break :blk true;
        }
        break :blk false;
    };
    
    const t2_out = blk: {
        const plane_origin = Vec3_mul_F(plane.n, -plane.d);
        const d = Vec3_dot(plane.n, Vec3_sub(triangle[2].pos, plane_origin));
        if (d < 0.0) {
            out_count += 1;
            break :blk true;
        }
        break :blk false;
    };
    
    if (out_count == 1) {
        
        var out_i: u32 = 0;
        if (!t0_out) {
            out_i = 1;
            if (!t1_out) out_i = 2;
        }
        const in_i1 = (out_i + 1) % 3;
        const in_i2 = (out_i + 2) % 3;
        
        var dir = Vec3_normalize(Vec3_sub(triangle[out_i].pos, triangle[in_i1].pos));
        const pos1 = lineIntersectPlane(triangle[in_i1].pos, dir, plane).?;
        
        dir = Vec3_normalize(Vec3_sub(triangle[out_i].pos, triangle[in_i2].pos));
        const pos2 = lineIntersectPlane(triangle[in_i2].pos, dir, plane).?;
        
        result.triangle0[out_i].pos = pos1;
        
        result.triangle1[out_i].pos = pos2;
        result.triangle1[in_i1].pos = pos1;
        
        result.count = 2;
    } else if (out_count == 2) {
        result.count = 1;
        
        var in_i: u32 = 0;
        if (t0_out) {
            in_i = 1;
            if (t1_out) in_i = 2;
        }
        const out_i1 = (in_i + 1) % 3;
        const out_i2 = (in_i + 2) % 3;
        
        const dir1 = Vec3_normalize(Vec3_sub(triangle[out_i1].pos, triangle[in_i].pos));
        const dir2 = Vec3_normalize(Vec3_sub(triangle[out_i2].pos, triangle[in_i].pos));
        result.triangle0[out_i1].pos = lineIntersectPlane(triangle[in_i].pos, dir1, plane).?;
        result.triangle0[out_i2].pos = lineIntersectPlane(triangle[in_i].pos, dir2, plane).?;
        
    } else if (out_count == 3) {
        result.count = 0;
    }
    
    return result;
}

pub fn drawMesh(mesh: Mesh, mode: RasterMode, proj_matrix: [4][4]f32,
                cam: Camera3D) void
{
    var index: u32 = 0;
    main_loop: while (index < mesh.i.len - 2) : (index += 3) {
        const ia = mesh.i[index];
        const ib = mesh.i[index + 1];
        const ic = mesh.i[index + 2];
        
        var triangle = [_]Vertex{mesh.v[ia], mesh.v[ib], mesh.v[ic]};
        
        // Calculate normal
        var n = Vec3{};
        {
            const a = Vec3_sub(triangle[1].pos, triangle[0].pos);
            const b = Vec3_sub(triangle[2].pos, triangle[0].pos);
            n = Vec3_normalize( Vec3_cross(a, b) );
        }
        
        const face_normal_dir = Vec3_dot(n, Vec3_sub(triangle[0].pos, cam.pos));
        if (face_normal_dir > 0.0) continue;
        
        // Lighting
        var dp: f32 = 0.0;
        {
            var ld = Vec3_normalize(Vec3.c(0.0, 1.0, 1.0));
            dp = Vec3_dot(ld, n);
            if (dp < 0.1) dp = 0.1;
        }
        
        var triangle_l: [16][3]Vertex = undefined;
        var triangle_l_len: u32 = 1;
        triangle_l[0] = triangle;
        
        {
            var i: u32 = 0;
            
            // Camera Translate
            while (i < 3) : (i += 1) {
                triangle_l[0][i].pos = Vec3_sub(triangle[i].pos, cam.pos);
            }
            
            { // clip near
                const cliping_result = clipTriangle(triangle_l[0], Plane.c(0, 0, -1, -0.1));
                if (cliping_result.count == 0) continue : main_loop;
                triangle_l[0] = cliping_result.triangle0;
                if (cliping_result.count == 2) {
                    triangle_l[1] = cliping_result.triangle1;
                    triangle_l_len += 1;
                }
            }
            
            { // clip far
                const cliping_result = clipTriangle(triangle_l[0], Plane.c(0, 0, 1, 100.0));
                if (cliping_result.count == 0) continue : main_loop;
                triangle_l[0] = cliping_result.triangle0;
            }
            
            // Projection
            var j: u32 = 0;
            while (j < triangle_l_len) : (j += 1) {
                i = 0;
                while (i < 3) : (i += 1) {
                    var new_t = Vec3{};
                    new_t.x = proj_matrix[0][0] * triangle_l[j][i].pos.x;
                    new_t.y = proj_matrix[1][1] * triangle_l[j][i].pos.y;
                    new_t.z = proj_matrix[2][2] * triangle_l[j][i].pos.z + proj_matrix[2][3];
                    const new_w = proj_matrix[3][2] * triangle_l[j][i].pos.z + proj_matrix[3][3];
                    triangle_l[j][i].w = new_w;
                    triangle_l[j][i].pos = Vec3_div_F(new_t, new_w);
                }
            }
        }
        
        // Cliping on the side
        const planes = [_]Plane {
            Plane.c(-1, 0, 0, 1),
            Plane.c(1, 0, 0, 1),
            Plane.c(0, 1, 0, 1),
            Plane.c(0, -1, 0, 1),
        };
        
        for (planes) |plane| {
            var tl_index: u32 = 0;
            const len = triangle_l_len;
            while (tl_index < len) : (tl_index += 1) {
                const cliping_result = clipTriangle(triangle_l[tl_index], plane);
                
                if (cliping_result.count == 0) {
                    for (triangle_l[tl_index..triangle_l_len]) |*it, i| {
                        it.* = triangle_l[tl_index + i + 1];
                    }
                    triangle_l_len -= 1;
                } else if (cliping_result.count == 1) {
                    triangle_l[tl_index] = cliping_result.triangle0;
                } else if (cliping_result.count == 2) {
                    triangle_l[tl_index] = cliping_result.triangle0;
                    
                    triangle_l[triangle_l_len] = cliping_result.triangle1;
                    triangle_l_len += 1;
                }
            }
        }
        
        if (triangle_l_len == 0) continue : main_loop;
        
        var tl_index: u32 = 0;
        while (tl_index < triangle_l_len) : (tl_index += 1) {
            triangle = triangle_l[tl_index];
            
            const pixel_size_y = 1.0 / @intToFloat(f32, win_height);
            const pixel_size_x = 1.0 / @intToFloat(f32, win_width);
            
            const pa_x = @floatToInt(i32, (triangle[0].pos.x + 1) / (2 * pixel_size_x));
            const pa_y = @floatToInt(i32, (-triangle[0].pos.y + 1) / (2 * pixel_size_y));
            
            const pb_x = @floatToInt(i32, (triangle[1].pos.x + 1) / (2 * pixel_size_x));
            const pb_y = @floatToInt(i32, (-triangle[1].pos.y + 1) / (2 * pixel_size_y));
            
            const pc_x = @floatToInt(i32, (triangle[2].pos.x + 1) / (2 * pixel_size_x));
            const pc_y = @floatToInt(i32, (-triangle[2].pos.y + 1) / (2 * pixel_size_y));
            
            switch (mode) {
                .Points => {
                    fillCircle(pa_x, pa_y, 5, triangle[0].color);
                    fillCircle(pb_x, pb_y, 5, triangle[1].color);
                    fillCircle(pc_x, pc_y, 5, triangle[2].color);
                    
                },
                .Lines => {
                    const line_color = Color.c(1, 1, 1, 1);
                    drawTriangle(pa_x, pa_y, pb_x, pb_y, pc_x, pc_y, line_color, 1);
                },
                .Faces => {
                    var color = triangle[0].color;
                    color.r *= dp;
                    color.g *= dp;
                    color.b *= dp;
                    fillTriangle(pa_x, pa_y, pb_x, pb_y, pc_x, pc_y, color);
                },
            }
        }
    }
}

const f32_4x = std.meta.Vector(4, f32);
const f32_8x = std.meta.Vector(8, f32);

fn rasterHalfTriangle(mesh: Mesh, i_up: u32, i_mid: u32, i_down: u32,
                      ia: u32, ib: u32, ic: u32, upper_triangle: bool) void
{}

// NOTE(Samuel): Do not try to optimize before making it work
fn rasterHalfTriangleButIsAVeryBadImplementation(mesh: Mesh, i_up: u32, i_mid: u32, i_down: u32,
                                                 ia: u32, ib: u32, ic: u32, upper_triangle: bool) void
{
    const pixel_size_x = 1.0 / @intToFloat(f32, win_width);
    const pixel_size_y = 1.0 / @intToFloat(f32, win_height);
    
    var atan1: f32 = 0.0;
    var atan2: f32 = 0.0;
    
    if (upper_triangle) {
        atan1 = (mesh.x[i_down] - mesh.x[i_up]) / (mesh.y[i_down] - mesh.y[i_up]);
        atan2 = (mesh.x[i_mid] - mesh.x[i_up]) / (mesh.y[i_mid] - mesh.y[i_up]);
    } else {
        atan1 = (mesh.x[i_up] - mesh.x[i_down]) / (mesh.y[i_up] - mesh.y[i_down]);
        atan2 = (mesh.x[i_mid] - mesh.x[i_down]) / (mesh.y[i_mid] - mesh.y[i_down]);
    }
    
    var dx1: f32 = 0;
    var dx2: f32 = 0;
    
    if (mesh.x[i_mid] < mesh.x[i_down]) {
        dx1 = pixel_size_y * atan2;
        dx2 = pixel_size_y * atan1;
    } else {
        dx1 = pixel_size_y * atan1;
        dx2 = pixel_size_y * atan2;
    }
    
    //if (@fabs(dx1) > 0.2) dx1 = 0.2 * @fabs(dx1) / dx1;
    //if (@fabs(dx2) > 0.2) dx1 = 0.2 * @fabs(dx1) / dx1;
    
    var x1:  f32 = 0.0;
    var x2: f32 = 0.0;
    var y:  f32 = 0.0;
    
    if (upper_triangle) {
        x1  = mesh.x[i_up];
        x2 = mesh.x[i_up];
        y  = mesh.y[i_up];
    } else {
        x1  = mesh.x[i_down];
        x2 = mesh.x[i_down];
        y  = mesh.y[i_down] - pixel_size_y;
    }
    
    const area = edgeFunction(mesh.x[ia], mesh.y[ia], mesh.x[ib],
                              mesh.y[ib], mesh.x[ic], mesh.y[ic]);
    
    const yc_minus_yb = mesh.y[ic] - mesh.y[ib];
    const ya_minus_yc = mesh.y[ia] - mesh.y[ic];
    const yb_minus_ya = mesh.y[ib] - mesh.y[ia];
    
    const xc_minus_xb = mesh.x[ic] - mesh.x[ib];
    const xa_minus_xc = mesh.x[ia] - mesh.x[ic];
    const xb_minus_xa = mesh.x[ib] - mesh.x[ia];
    
    const yc_minus_yb_4x = @splat(4, yc_minus_yb);
    const ya_minus_yc_4x = @splat(4, ya_minus_yc);
    const yb_minus_ya_4x = @splat(4, yb_minus_ya);
    
    const xc_minus_xb_4x = @splat(4, xc_minus_xb);
    const xa_minus_xc_4x = @splat(4, xa_minus_xc);
    const xb_minus_xa_4x = @splat(4, xb_minus_xa);
    
    const mesh_x_ia_4x = @splat(4, mesh.x[ia]);
    const mesh_x_ib_4x = @splat(4, mesh.x[ib]);
    const mesh_x_ic_4x = @splat(4, mesh.x[ic]);
    
    const mesh_y_ia_4x = @splat(4, mesh.y[ia]);
    const mesh_y_ib_4x = @splat(4, mesh.y[ib]);
    const mesh_y_ic_4x = @splat(4, mesh.y[ic]);
    
    const mesh_z_ia_4x = @splat(4, mesh.z[ia]);
    const mesh_z_ib_4x = @splat(4, mesh.z[ib]);
    const mesh_z_ic_4x = @splat(4, mesh.z[ic]);
    
    const mesh_w_ia_4x = @splat(4, mesh.w[ia]);
    const mesh_w_ib_4x = @splat(4, mesh.w[ib]);
    const mesh_w_ic_4x = @splat(4, mesh.w[ic]);
    
    const area_4x = @splat(4, area);
    
    const mcolor_ia = f32_4x{mesh.colors[ia].r, mesh.colors[ia].g, mesh.colors[ia].b, mesh.colors[ia].a};
    const mcolor_ib = f32_4x{mesh.colors[ib].r, mesh.colors[ib].g, mesh.colors[ib].b, mesh.colors[ib].a};
    const mcolor_ic = f32_4x{mesh.colors[ic].r, mesh.colors[ic].g, mesh.colors[ic].b, mesh.colors[ic].a};
    
    const ua_4x = @splat(4, mesh.u[ia]);
    const ub_4x = @splat(4, mesh.u[ib]);
    const uc_4x = @splat(4, mesh.u[ic]);
    
    const va_4x = @splat(4, mesh.v[ia]);
    const vb_4x = @splat(4, mesh.v[ib]);
    const vc_4x = @splat(4, mesh.v[ic]);
    const one_4x = @splat(4, @as(f32, 1.0));
    
    const w0_base = (mesh_y_ib_4x * xc_minus_xb_4x - mesh_x_ic_4x * yc_minus_yb_4x) / area_4x;
    const w1_base = (mesh_y_ic_4x * xa_minus_xc_4x - mesh_x_ic_4x * ya_minus_yc_4x) / area_4x;
    
    while (true) {
        if (upper_triangle) {
            if (!(y > mesh.y[i_mid] - pixel_size_y)) break;
        } else {
            if (!(y < mesh.y[i_mid] + pixel_size_y)) break;
        }
        
        const yp  = @floatToInt(i32, (-y  + 1) * 0.5 / pixel_size_y);
        const xp2 = @floatToInt(i32, (x2 + 1)  * 0.5 / pixel_size_x);
        var xp  = @floatToInt(i32, (x1  + 1)  * 0.5 / pixel_size_x);
        
        var x = x1;
        const x_inc = pixel_size_x * 2;
        
        const y_4x = @splat(4, y);
        const x_inc_4x = f32_4x{0, x_inc, x_inc*2, x_inc*3};
        
        const w0_base2 = (y_4x * xc_minus_xb_4x) / area_4x - w0_base;
        const w1_base2 = (y_4x * xa_minus_xc_4x) / area_4x - w1_base;
        
        while (xp < xp2) : (xp += 4) {
            const x_4x = @splat(4, x) + x_inc_4x;
            
            // TODO(Samuel): Optimize this out by pre calculating and incrementing the interpolation
            var w0 = (x_4x * yc_minus_yb_4x) / area_4x - w0_base2;
            var w1 = (x_4x * ya_minus_yc_4x) / area_4x - w1_base2;
            var w2 = one_4x - w0 - w1;
            
            // NOTE(Samuel): Perspective correct interpolation
            if (true) {
                w0 /= mesh_w_ia_4x;
                w1 /= mesh_w_ib_4x;
                w2 /= mesh_w_ic_4x;
                const w_sum = w0 + w1 + w2;
                w0 /= w_sum;
                w1 /= w_sum;
                w2 /= w_sum;
            }
            const one_over_z_4x = w0 * (one_4x / mesh_z_ia_4x) + w1 * (one_4x / mesh_z_ib_4x) + w2 * (one_4x / mesh_z_ic_4x);
            
            const z_4x = one_4x / one_over_z_4x;
            
            var u_4x = ua_4x * w0 + ub_4x * w1 + uc_4x * w2;
            var v_4x = va_4x * w0 + vb_4x * w1 + vc_4x * w2;
            
            var i: u32 = 0;
            while (i < 4) : (i += 1) {
                const w0_4x = @splat(4, w0[i]);
                const w1_4x = @splat(4, w1[i]);
                const w2_4x = @splat(4, w2[i]);
                
                var color = mcolor_ia * w0_4x + mcolor_ib * w1_4x + mcolor_ic * w2_4x;
                
                // TODO(Samuel): Inline and SIMD texture mapping
                //var color: f32_4x = textureMap(u_4x[i], v_4x[i], mesh.texture);
                
                //color *= @splat(4, z);
                //std.debug.print("{} {} {} {}\n", .{color[0], color[1], color[2], color[3]});
                
                const _i = @intCast(i32, i);
                if (xp + _i < xp2)  {
                    
                    // HACK(Samuel): Remove this
                    const _x = @intCast(u32, std.math.clamp(xp + _i, 0, @intCast(i32, win_width) - 1));
                    const _y = @intCast(u32, std.math.clamp(yp, 0, @intCast(i32, win_height) - 1));
                    
                    //std.debug.print("{d}\n", .{z_4x[i]});
                    const depth_index = _x + _y * win_width;
                    if (z_4x[i] <= depth_buffer[depth_index]) {
                        depth_buffer[depth_index] = z_4x[i];
                    } else {
                        continue;
                    }
                    
                    const pixel = screen_buffer[(_x + _y * win_width) * 4 ..][0..3];
                    if (color[3] > 0.999) {
                        pixel[0] = @floatToInt(u8, color[0] * 255);
                        pixel[1] = @floatToInt(u8, color[1] * 255);
                        pixel[2] = @floatToInt(u8, color[2] * 255);
                        
                        //pixel[0] = @floatToInt(u8, depth_buffer[depth_index] * 255);
                        //pixel[1] = @floatToInt(u8, depth_buffer[depth_index] * 255);
                        //pixel[2] = @floatToInt(u8, depth_buffer[depth_index] * 255);
                        
                        //pixel[0] = @floatToInt(u8, z_4x[i] * 255);
                        //pixel[1] = @floatToInt(u8, z_4x[i] * 255);
                        //pixel[2] = @floatToInt(u8, z_4x[i] * 255);
                    }
                }
            }
            
            x += x_inc * 4;
        }
        
        if (upper_triangle) {
            x1 -= dx1;
            x2 -= dx2;
            y -= pixel_size_y;
        } else {
            x1 += dx1;
            x2 += dx2;
            y += pixel_size_y;
        }
    }
}
