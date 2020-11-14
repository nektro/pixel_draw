const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const util = @import("util.zig");
usingnamespace util;

usingnamespace if (@import("builtin").os.tag == .windows)
@import("win32_plataform.zig")
else
@import("xlib_plataform.zig");

pub const vector_math = @import("vector_math.zig");
usingnamespace vector_math;

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

pub var screen_buffer: []u8 = undefined;
pub var depth_buffer: []f32 = undefined;

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

pub inline fn keyStrengh(key: Keys) f32 {
    return @intToFloat(f32, @boolToInt(keyPressed(key)));
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
pub inline fn textureMap(u: f32, v: f32, tex: Texture) Color {
    const tex_u = @floatToInt(u32, (@intToFloat(f32, tex.width) * u)) % tex.width;
    const tex_v = @floatToInt(u32, (@intToFloat(f32, tex.height) * v)) % tex.height;
    
    const tex_pos = (tex_u + tex_v * tex.height) * 4;
    const pixel = tex.raw[tex_pos..][0..4];
    return Color{
        .r = @intToFloat(f32, pixel[2]) / 255.0,
        .g = @intToFloat(f32, pixel[1]) / 255.0,
        .b = @intToFloat(f32, pixel[0]) / 255.0,
        .a = @intToFloat(f32, pixel[3]) / 255.0,
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
    const header: *const BmpHeader = @ptrCast(*const BmpHeader, bmp_data[0..@sizeOf(BmpHeader)]);
    
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
                putPixel(x + u, y + v, color);
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

pub fn drawBitmapFont(text: []const u8, x: u32, y: u32, scale_x: u32, scale_y: u32, font: BitmapFont) void {
    for (text) |t, i| {
        const char_index: u32 = t;
        const fx = char_index % 16 * font.font_size_x;
        const fy = char_index / 16 * font.font_size_y;
        
        const x_pos = x + @intCast(u32, i) * scale_x * font.character_spacing;
        drawBitmapChar(t, x_pos, y, scale_x, scale_y, font);
    }
}

// TODO(Samuel): Optimize this function
pub fn drawBitmapChar(char: u8, x: u32, y: u32, scale_x: u32, scale_y: u32, font: BitmapFont) void {
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
                    const x_pos = x + xi * scale_x + sx;
                    const y_pos = y + yi * scale_y + sy;
                    putPixelRGBA(x_pos, y_pos, color[0], color[1], color[2], color[3]);
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

/// draw a line with a width of 1 pixel
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

/// Draw a line with a width defined by line_width
pub fn drawLineWidth(xa: i32, ya: i32, xb: i32, yb: i32, color: Color, line_width: u32) void {
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

pub inline fn drawTriangle(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32, color: Color, line_width: u32) void {
    drawLineWidth(xa, ya, xb, yb, color, line_width);
    drawLineWidth(xb, yb, xc, yc, color, line_width);
    drawLineWidth(xc, yc, xa, ya, color, line_width);
}

pub fn fillTriangle(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32, color: Color) void {
    const x_left = math.min(math.min(xa, xb), math.max(xc, 0));
    const x_right = math.max(math.max(xa, xb), math.min(xc, @intCast(i32, win_width)));
    const y_up = math.min(math.min(ya, yb), math.max(yc, 0));
    const y_down = math.max(math.max(ya, yb), math.min(yc, @intCast(i32, win_height)));
    
    var y: i32 = y_up;
    while (y < y_down) : (y += 1) {
        var x: i32 = x_left;
        while (x < x_right) : (x += 1) {
            var w0 = edgeFunctionI(xb, yb, xc, yc, x, y);
            var w1 = edgeFunctionI(xc, yc, xa, ya, x, y);
            var w2 = edgeFunctionI(xa, ya, xb, yb, x, y);
            
            if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                putPixel(x, y, color);
            }
        }
    }
}

/// Converts screen coordinates (-1, 1) to pixel coordinates (0, screen size)
pub inline fn screenToPixel(sc: f32, screen_size: u32) i32 {
    return @floatToInt(i32, (sc + 1.0) * 0.5 * @intToFloat(f32, screen_size));
}

/// Raster a triangle
pub fn rasterTriangleOld(triangle: [3]Vertex, texture: Texture, face_lighting: f32) void {
    const xa = screenToPixel(triangle[0].pos.x, win_width);
    const xb = screenToPixel(triangle[1].pos.x, win_width);
    const xc = screenToPixel(triangle[2].pos.x, win_width);
    
    const ya = screenToPixel(-triangle[0].pos.y, win_height);
    const yb = screenToPixel(-triangle[1].pos.y, win_height);
    const yc = screenToPixel(-triangle[2].pos.y, win_height);
    
    const x_left = math.max(math.min(math.min(xa, xb), xc), 0);
    const x_right = math.min(math.max(math.max(xa, xb), xc), @intCast(i32, win_width - 1));
    const y_up = math.max(math.min(math.min(ya, yb), yc), 0);
    const y_down = math.min(math.max(math.max(ya, yb), yc), @intCast(i32, win_height - 1));
    
    const w0_a = (yc - yb);
    const w1_a = (ya - yc);
    
    var y: i32 = y_up;
    while (y <= y_down) : (y += 1) {
        const area = @intToFloat(f32, edgeFunctionI(xa, ya, xb, yb, xc, yc));
        
        var x: i32 = x_left;
        const db_iy = y * @intCast(i32, win_width);
        
        const w0_b = (y - yb) * (xc - xb);
        const w1_b = (y - yc) * (xa - xc);
        
        while (x <= x_right) : (x += 1) {
            const w0i = (x - xb) * w0_a - w0_b;
            const w1i = (x - xc) * w1_a - w1_b;
            
            var w0 = @intToFloat(f32, w0i) / area;
            var w1 = @intToFloat(f32, w1i) / area;
            var w2 = 1.0 - w0 - w1;
            
            if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                // NOTE(Samuel): Correct for perpective
                w0 /= triangle[0].w;
                w1 /= triangle[1].w;
                w2 /= triangle[2].w;
                const w_sum = w0 + w1 + w2;
                w0 /= w_sum;
                w1 /= w_sum;
                w2 /= w_sum;
                
                var db_i = @intCast(u32, x + db_iy);
                const z = triangle[0].w * w0 + triangle[1].w * w1 + triangle[2].w * w2;
                
                if (depth_buffer[db_i] > z) {
                    depth_buffer[db_i] = z;
                    
                    var uv: Vec2 = .{};
                    uv.x = triangle[0].uv.x * w0 + triangle[1].uv.x * w1 + triangle[2].uv.x * w2;
                    uv.y = triangle[0].uv.y * w0 + triangle[1].uv.y * w1 + triangle[2].uv.y * w2;
                    var color = textureMap(uv.x, uv.y, texture);
                    color.r *= face_lighting;
                    color.g *= face_lighting;
                    color.b *= face_lighting;
                    putPixel(x, y, color);
                }
            }
        }
    }
}

/// Raster a triangle
pub fn rasterTriangle(triangle: [3]Vertex, texture: Texture, face_lighting: f32) void {
    @setFloatMode(.Optimized);
    
    const face_lighting_i = @floatToInt(u16, face_lighting * 255);
    
    const xa = screenToPixel(triangle[0].pos.x, win_width);
    const xb = screenToPixel(triangle[1].pos.x, win_width);
    const xc = screenToPixel(triangle[2].pos.x, win_width);
    
    const ya = screenToPixel(-triangle[0].pos.y, win_height);
    const yb = screenToPixel(-triangle[1].pos.y, win_height);
    const yc = screenToPixel(-triangle[2].pos.y, win_height);
    
    const x_left = math.max(math.min(math.min(xa, xb), xc), 0);
    const x_right = math.min(math.max(math.max(xa, xb), xc), @intCast(i32, win_width - 1));
    const y_up = math.max(math.min(math.min(ya, yb), yc), 0);
    const y_down = math.min(math.max(math.max(ya, yb), yc), @intCast(i32, win_height - 1));
    
    const w0_a = @intToFloat(f32, yc - yb);
    const w1_a = @intToFloat(f32, ya - yc);
    const area = @intToFloat(f32, edgeFunctionI(xa, ya, xb, yb, xc, yc));
    
    if (area < 0.0001 and area > -0.0001) return;
    
    const w0_a_4x = @splat(4, w0_a);
    const w1_a_4x = @splat(4, w1_a);
    const area_4x = @splat(4, area);
    const one_4x = @splat(4, @as(f32, 1.0));
    const zero_4x = @splat(4, @as(f32, 0.0));
    const inc_4x: std.meta.Vector(4, f32) = .{ 0.0, 1.0, 2.0, 3.0 };
    const false_4x: std.meta.Vector(4, bool) = .{ false, false, false, false };
    
    const xb_4x = @splat(4, @intToFloat(f32, xb));
    const xc_4x = @splat(4, @intToFloat(f32, xc));
    
    const tri0_w_4x = @splat(4, triangle[0].w);
    const tri1_w_4x = @splat(4, triangle[1].w);
    const tri2_w_4x = @splat(4, triangle[2].w);
    
    const tri0_u_4x = @splat(4, triangle[0].uv.x);
    const tri1_u_4x = @splat(4, triangle[1].uv.x);
    const tri2_u_4x = @splat(4, triangle[2].uv.x);
    
    const tri0_v_4x = @splat(4, triangle[0].uv.y);
    const tri1_v_4x = @splat(4, triangle[1].uv.y);
    const tri2_v_4x = @splat(4, triangle[2].uv.y);
    
    const tex_width_4x = @splat(4, @intToFloat(f32, texture.width));
    const tex_height_4x = @splat(4, @intToFloat(f32, texture.height));
    
    var y: i32 = y_up;
    while (y <= y_down) : (y += 1) {
        var x: i32 = x_left;
        const db_iy = y * @intCast(i32, win_width);
        
        const w0_b = @intToFloat(f32, (y -% yb) *% (xc -% xb));
        const w1_b = @intToFloat(f32, (y -% yc) *% (xa -% xc));
        
        const w0_b_4x = @splat(4, w0_b);
        const w1_b_4x = @splat(4, w1_b);
        
        while (x <= x_right) {
            const x_4x = @splat(4, @intToFloat(f32, x)) + inc_4x;
            var w0_4x = ((x_4x - xb_4x) * w0_a_4x - w0_b_4x) / area_4x;
            var w1_4x = ((x_4x - xc_4x) * w1_a_4x - w1_b_4x) / area_4x;
            var w2_4x = one_4x - w1_4x - w0_4x;
            
            const w0_cmp_4x = w0_4x < zero_4x;
            const w1_cmp_4x = w1_4x < zero_4x;
            const w2_cmp_4x = w2_4x < zero_4x;
            
            if (@reduce(.And, w0_cmp_4x)) {
                x += 4;
                continue;
            }
            if (@reduce(.And, w1_cmp_4x)) {
                x += 4;
                continue;
            }
            if (@reduce(.And, w2_cmp_4x)) {
                x += 4;
                continue;
            }
            
            w0_4x /= tri0_w_4x;
            w1_4x /= tri1_w_4x;
            w2_4x /= tri2_w_4x;
            const w_sum = w0_4x + w1_4x + w2_4x;
            w0_4x /= w_sum;
            w1_4x /= w_sum;
            w2_4x /= w_sum;
            
            var db_i = @intCast(u32, x + db_iy);
            db_i = math.min(db_i, win_width * win_height - 4);
            
            var depth_slice = depth_buffer[db_i..][0..4];
            const depth_4x: std.meta.Vector(4, f32) = depth_slice.*;
            
            const z_4x = tri0_w_4x * w0_4x + tri1_w_4x * w1_4x + tri2_w_4x * w2_4x;
            const z_mask_4x = depth_4x < z_4x;
            
            if (@reduce(.And, z_mask_4x)) {
                x += 4;
                continue;
            }
            
            //for (depth_slice) |*it, i| it.* = z_4x[i];
            
            var u_4x = tri0_u_4x * w0_4x + tri1_u_4x * w1_4x + tri2_u_4x * w2_4x;
            var v_4x = tri0_v_4x * w0_4x + tri1_v_4x * w1_4x + tri2_v_4x * w2_4x;
            
            u_4x *= tex_width_4x;
            v_4x *= tex_height_4x;
            
            var i: u32 = 0;
            while (i < 4 and x < win_width) : (i += 1) {
                var w0 = w0_4x[i];
                var w1 = w1_4x[i];
                var w2 = w2_4x[i];
                
                if (!(w0_cmp_4x[i] or w1_cmp_4x[i] or w2_cmp_4x[i])) {
                    const z = z_4x[i];
                    if (!z_mask_4x[i]) {
                        depth_slice[i] = z;
                        
                        var color = Color{};
                        
                        const tex_u = @floatToInt(u32, u_4x[i]) % texture.width;
                        const tex_v = @floatToInt(u32, v_4x[i]) % texture.height;
                        
                        const tex_pos = (tex_u + tex_v * texture.height) * 4;
                        var tpixel = texture.raw[tex_pos..][0..4].*;
                        
                        tpixel[0] = @intCast(u8, tpixel[0] * face_lighting_i / 255);
                        tpixel[1] = @intCast(u8, tpixel[1] * face_lighting_i / 255);
                        tpixel[2] = @intCast(u8, tpixel[2] * face_lighting_i / 255);
                        
                        const pixel_pos = @intCast(u32, x + y * @intCast(i32, win_width)) * 4;
                        const pixel = screen_buffer[pixel_pos..][0..4];
                        
                        if (tpixel[3] > 0) {
                            pixel[0] = tpixel[0];
                            pixel[1] = tpixel[1];
                            pixel[2] = tpixel[2];
                        }
                    }
                }
                
                x += 1;
            }
        }
    }
}

// ==== 3d stuff ====

pub const Mesh = struct {
    v: []Vertex,
    i: []u32,
    texture: Texture,
};

pub const TextureMode = enum {
    Strech,
    Tile,
};

/// Creates a mesh made with quads with a given size. vertex colors are random
pub fn createQuadMesh(al: *Allocator, size_x: u32, size_y: u32, center_x: f32, center_y: f32, texture: Texture, texture_mode: TextureMode) Mesh {
    var result = Mesh{
        .v = al.alloc(Vertex, (size_x + 1) * (size_y + 1)) catch unreachable,
        .i = al.alloc(u32, size_x * size_y * 6) catch unreachable,
        .texture = texture,
    };
    
    // Init Vertex
    for (result.v) |*v, i| {
        v.pos.x = @intToFloat(f32, i % (size_x + 1)) - center_x;
        v.pos.y = @intToFloat(f32, i / (size_x + 1)) - center_y;
        v.pos.z = 0.0;
        
        //v.color.a = 1.0;
        //v.color.r = randomFloat(f32);
        //v.color.g = randomFloat(f32);
        //v.color.b = randomFloat(f32);
    }
    
    if (texture_mode == .Strech) {
        for (result.v) |*v, i| {
            v.uv.x = (v.pos.x + center_x) / @intToFloat(f32, size_x);
            v.uv.y = (v.pos.y + center_y) / @intToFloat(f32, size_y);
        }
    } else if (texture_mode == .Tile) {
        for (result.v) |*v, i| {
            const x_i = @intCast(u32, i % (size_x + 1));
            const y_i = @intCast(u32, i / (size_x + 1));
            v.uv.x = @intToFloat(f32, x_i % 2);
            v.uv.y = @intToFloat(f32, y_i % 2);
        }
    }
    
    // Set indexes
    var index: u32 = 0;
    var y: u32 = 0;
    while (y < size_y) : (y += 1) {
        var x: u32 = 0;
        while (x < size_x) : (x += 1) {
            // first triangle
            var i = x + y * (size_x + 1);
            result.i[index] = i;
            index += 1;
            
            i = (x + 1) + (y + 1) * (size_x + 1);
            result.i[index] = i;
            index += 1;
            
            i = x + (y + 1) * (size_x + 1);
            result.i[index] = i;
            index += 1;
            
            // Second Triangle
            i = (x + 1) + y * (size_x + 1);
            result.i[index] = i;
            index += 1;
            
            i = (x + 1) + (y + 1) * (size_x + 1);
            result.i[index] = i;
            index += 1;
            
            i = x + y * (size_x + 1);
            result.i[index] = i;
            index += 1;
        }
    }
    
    return result;
}

pub fn meshFromObjData(al: *Allocator, obj_data: []const u8) Mesh {
    
    // find mesh size;
    var v_count: u32 = 0;
    var i_count: u32 = 0;
    var t_count: u32 = 0;
    
    var data = obj_data;
    while (true) {
        var line = nextLineSlice(&data);
        if (line.len == 0) break;
        
        removeTrailingSpaces(&line);
        removeLeadingSpaces(&line);
        
        var tok = getToken(&line, ' ');
        
        if (tok.len == 1) {
            if (tok[0] == 'f') {
                i_count += 3;
            } else if (tok[0] == 'v') {
                v_count += 1;
            }
        } else if (tok.len == 2) {
            if (tok[0] == 'v' and tok[1] == 't') {
                t_count += 1;
            }
        }
    }
    
    std.debug.print("The mesh has {} vetices and {} indexes and {} t\n", .{
                        v_count, i_count,
                        t_count,
                    });
    
    var vert = al.alloc(Vec3, v_count) catch unreachable;
    var uv = al.alloc(Vec2, t_count) catch unreachable;
    var vert_i = al.alloc(u32, i_count) catch unreachable;
    var uv_i = al.alloc(u32, i_count) catch unreachable;
    
    defer al.free(vert);
    defer al.free(uv);
    defer al.free(vert_i);
    defer al.free(uv_i);
    
    var vert_index: u32 = 0;
    var uv_index: u32 = 0;
    var vert_i_index: u32 = 0;
    var uv_i_index: u32 = 0;
    
    data = obj_data;
    while (true) {
        var line = nextLineSlice(&data);
        if (line.len == 0) break;
        
        removeTrailingSpaces(&line);
        removeLeadingSpaces(&line);
        
        const tok = getToken(&line, ' ');
        if (tok.len == 1) {
            if (tok[0] == 'f') {
                var _i: u32 = 0;
                while (_i < 3) : (_i += 1) {
                    var f = getToken(&line, ' ');
                    var vi = getToken(&f, '/');
                    var vt = getToken(&f, '/');
                    
                    vert_i[vert_i_index] = std.fmt.parseInt(u32, vi, 10) catch unreachable;
                    uv_i[uv_i_index] = std.fmt.parseInt(u32, vt, 10) catch unreachable;
                    
                    vert_i_index += 1;
                    uv_i_index += 1;
                }
            } else if (tok[0] == 'v') {
                var x = getToken(&line, ' ');
                var y = getToken(&line, ' ');
                var z = line;
                
                vert[vert_index].x = std.fmt.parseFloat(f32, x) catch unreachable;
                vert[vert_index].y = std.fmt.parseFloat(f32, y) catch unreachable;
                vert[vert_index].z = std.fmt.parseFloat(f32, z) catch unreachable;
                vert_index += 1;
            }
        } else if (tok.len == 2) {
            if (tok[0] == 'v' and tok[1] == 't') {
                var x = getToken(&line, ' ');
                var y = line;
                
                uv[uv_index].x = std.fmt.parseFloat(f32, x) catch unreachable;
                uv[uv_index].y = std.fmt.parseFloat(f32, y) catch unreachable;
                uv_index += 1;
            }
        }
    }
    
    var mesh_v_size = if (v_count > t_count) v_count else t_count;
    
    var result = Mesh{
        .v = al.alloc(Vertex, mesh_v_size) catch unreachable,
        .i = al.alloc(u32, i_count) catch unreachable,
        .texture = undefined,
    };
    
    for (result.i) |*i, _i| {
        if (v_count >= t_count) {
            i.* = vert_i[_i] - 1;
        } else {
            i.* = uv_i[_i] - 1;
        }
        
        result.v[i.*] = Vertex{
            .pos = vert[vert_i[_i] - 1],
            .uv = uv[uv_i[_i] - 1],
        };
    }
    
    return result;
}

const RasterMode = enum {
    Points,
    Lines,
    NoShadow,
    Texture,
};

pub const Camera3D = struct {
    pos: Vec3 = .{}, rotation: Vec3 = .{}, // Euler angles
    fov: f32 = 70, near: f32 = 0.1, far: f32 = 100.0
};

pub const ClipTriangleReturn = struct {
    triangle0: [3]Vertex,
    triangle1: [3]Vertex,
    count: u32 = 0,
};

pub fn clipTriangle(triangle: [3]Vertex, plane: Plane) ClipTriangleReturn {
    var result = ClipTriangleReturn{
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
        
        var t1: f32 = 0.0;
        var t2: f32 = 0.0;
        
        const pos1 = lineIntersectPlaneT(triangle[in_i1].pos, triangle[out_i].pos, plane, &t1);
        const pos2 = lineIntersectPlaneT(triangle[in_i2].pos, triangle[out_i].pos, plane, &t2);
        //const color1 = Color_lerp(triangle[in_i1].color, triangle[out_i].color, t1);
        //const color2 = Color_lerp(triangle[in_i2].color, triangle[out_i].color, t2);
        
        var uv1 = Vec2{};
        var uv2 = Vec2{};
        
        uv1.x = lerp(triangle[in_i1].uv.x, triangle[out_i].uv.x, t1);
        uv1.y = lerp(triangle[in_i1].uv.y, triangle[out_i].uv.y, t1);
        
        uv2.x = lerp(triangle[in_i2].uv.x, triangle[out_i].uv.x, t2);
        uv2.y = lerp(triangle[in_i2].uv.y, triangle[out_i].uv.y, t2);
        
        //result.triangle0[out_i].color = color1;
        //result.triangle1[in_i1].color = color1;
        //result.triangle1[out_i].color = color2;
        
        result.triangle0[out_i].pos = pos1;
        result.triangle1[in_i1].pos = pos1;
        result.triangle1[out_i].pos = pos2;
        
        result.triangle0[out_i].uv = uv1;
        result.triangle1[in_i1].uv = uv1;
        result.triangle1[out_i].uv = uv2;
        
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
        
        var t1: f32 = 0.0;
        var t2: f32 = 0.0;
        const pos1 = lineIntersectPlaneT(triangle[out_i1].pos, triangle[in_i].pos, plane, &t1);
        const pos2 = lineIntersectPlaneT(triangle[out_i2].pos, triangle[in_i].pos, plane, &t2);
        //const color1 = Color_lerp(triangle[out_i1].color, triangle[in_i].color, t1);
        //const color2 = Color_lerp(triangle[out_i2].color, triangle[in_i].color, t2);
        
        var uv1 = Vec2{};
        var uv2 = Vec2{};
        
        uv1.x = lerp(triangle[out_i1].uv.x, triangle[in_i].uv.x, t1);
        uv1.y = lerp(triangle[out_i1].uv.y, triangle[in_i].uv.y, t1);
        
        uv2.x = lerp(triangle[out_i2].uv.x, triangle[in_i].uv.x, t2);
        uv2.y = lerp(triangle[out_i2].uv.y, triangle[in_i].uv.y, t2);
        
        //result.triangle0[out_i1].color = color1;
        //result.triangle0[out_i2].color = color2;
        
        result.triangle0[out_i1].pos = pos1;
        result.triangle0[out_i2].pos = pos2;
        
        result.triangle0[out_i1].uv = uv1;
        result.triangle0[out_i2].uv = uv2;
    } else if (out_count == 3) {
        result.count = 0;
    }
    
    return result;
}

pub fn drawMesh(mesh: Mesh, mode: RasterMode, cam: Camera3D) void {
    const hw_ratio = @intToFloat(f32, win_height) /
        @intToFloat(f32, win_width);
    const proj_matrix = perspectiveMatrix(cam.near, cam.far, cam.fov, hw_ratio);
    
    var index: u32 = 0;
    main_loop: while (index < mesh.i.len - 2) : (index += 3) {
        const ia = mesh.i[index];
        const ib = mesh.i[index + 1];
        const ic = mesh.i[index + 2];
        
        var triangle = [_]Vertex{ mesh.v[ia], mesh.v[ib], mesh.v[ic] };
        
        // Calculate normal
        var n = Vec3{};
        {
            const a = Vec3_sub(triangle[1].pos, triangle[0].pos);
            const b = Vec3_sub(triangle[2].pos, triangle[0].pos);
            n = Vec3_normalize(Vec3_cross(a, b));
        }
        
        const face_normal_dir = Vec3_dot(n, Vec3_sub(triangle[0].pos, cam.pos));
        if (face_normal_dir > 0.0) continue;
        
        // Lighting
        var face_lighting: f32 = 0.0;
        {
            var ld = Vec3_normalize(Vec3.c(0.5, 1.0, 1.0));
            
            face_lighting = Vec3_dot(ld, n);
            if (face_lighting < 0.1) face_lighting = 0.1;
        }
        
        var triangle_l: [16][3]Vertex = undefined;
        var triangle_l_len: u32 = 1;
        triangle_l[0] = triangle;
        
        // Camera Trasform
        {
            var i: u32 = 0;
            while (i < 3) : (i += 1) {
                triangle_l[0][i].pos = Vec3_sub(triangle[i].pos, cam.pos);
                
                triangle_l[0][i].pos = rotateVectorOnY(triangle_l[0][i].pos, cam.rotation.y);
                
                triangle_l[0][i].pos = rotateVectorOnX(triangle_l[0][i].pos, cam.rotation.x);
            }
        }
        
        { // clip near
            const cliping_result = clipTriangle(triangle_l[0], Plane.c(0, 0, -1, -cam.near));
            if (cliping_result.count == 0) continue :main_loop;
            triangle_l[0] = cliping_result.triangle0;
            if (cliping_result.count == 2) {
                triangle_l_len += 1;
                triangle_l[1] = cliping_result.triangle1;
            }
        }
        
        { // clip far
            const cliping_result = clipTriangle(triangle_l[0], Plane.c(0, 0, 1, cam.far));
            if (cliping_result.count == 0) continue :main_loop;
            triangle_l[0] = cliping_result.triangle0;
        }
        
        // Projection
        var j: u32 = 0;
        while (j < triangle_l_len) : (j += 1) {
            var i: u32 = 0;
            while (i < 3) : (i += 1) {
                var new_t = Vec3{};
                new_t.x = proj_matrix[0][0] * triangle_l[j][i].pos.x;
                new_t.y = proj_matrix[1][1] * triangle_l[j][i].pos.y;
                new_t.z = proj_matrix[2][2] * triangle_l[j][i].pos.z + proj_matrix[2][3];
                const new_w = proj_matrix[3][2] * triangle_l[j][i].pos.z + proj_matrix[3][3];
                triangle_l[j][i].w = new_w;
                //std.debug.print("w = {d:0.4}\n", .{new_w});
                triangle_l[j][i].pos = Vec3_div_F(new_t, new_w);
            }
        }
        
        // Cliping on the side
        const planes = [_]Plane{
            Plane.c(-1, 0, 0, 1),
            Plane.c(1, 0, 0, 1),
            Plane.c(0, 1, 0, 1),
            Plane.c(0, -1, 0, 1),
        };
        
        // NOTE(Samuel): Cliping on the side
        // HACK(Samuel): On the side I'm only cliping triangles that are completly outside of the screen
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
                }
            }
        }
        
        if (triangle_l_len == 0) continue :main_loop;
        
        var tl_index: u32 = 0;
        while (tl_index < triangle_l_len) : (tl_index += 1) {
            triangle = triangle_l[tl_index];
            
            switch (mode) {
                .Points, .Lines => {
                    const pixel_size_y = 1.0 / @intToFloat(f32, win_height);
                    const pixel_size_x = 1.0 / @intToFloat(f32, win_width);
                    
                    const pa_x = @floatToInt(i32, (triangle[0].pos.x + 1) / (2 * pixel_size_x));
                    const pa_y = @floatToInt(i32, (-triangle[0].pos.y + 1) / (2 * pixel_size_y));
                    
                    const pb_x = @floatToInt(i32, (triangle[1].pos.x + 1) / (2 * pixel_size_x));
                    const pb_y = @floatToInt(i32, (-triangle[1].pos.y + 1) / (2 * pixel_size_y));
                    
                    const pc_x = @floatToInt(i32, (triangle[2].pos.x + 1) / (2 * pixel_size_x));
                    const pc_y = @floatToInt(i32, (-triangle[2].pos.y + 1) / (2 * pixel_size_y));
                    
                    if (mode == .Points) {
                        fillCircle(pa_x, pa_y, 5, Color.c(1, 1, 1, 1));
                        fillCircle(pb_x, pb_y, 5, Color.c(1, 1, 1, 1));
                        fillCircle(pc_x, pc_y, 5, Color.c(1, 1, 1, 1));
                    } else if (mode == .Lines) {
                        const line_color = Color.c(1, 1, 1, 1);
                        drawTriangle(pa_x, pa_y, pb_x, pb_y, pc_x, pc_y, line_color, 1);
                    }
                },
                .NoShadow => {
                    rasterTriangle(triangle, mesh.texture, 1.0);
                },
                .Texture => {
                    rasterTriangle(triangle, mesh.texture, face_lighting);
                },
            }
        }
    }
}
