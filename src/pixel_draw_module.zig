const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const util = @import("util.zig");
usingnamespace util;

pub const vector_math = @import("vector_math.zig");
usingnamespace vector_math;


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

/// Maps a u and v value, from 0 to 1, to a pixel on a texture and returns the pixel color
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

/// Return a color from rgba values, 0 to 255
pub fn colorFromRgba(r: u8, g: u8, b: u8, a: u8) Color {
    return Color{
        .r = @intToFloat(f32, r) / 255.0,
        .g = @intToFloat(f32, g) / 255.0,
        .b = @intToFloat(f32, b) / 255.0,
        .a = @intToFloat(f32, a) / 255.0,
    };
}

/// Return a texture from a BMP data, it does not do a allocation, the BMP data pointer is passed directly to the texture data
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

/// Load a BMP file and returns a Texture. Memory must be freed by the caller
pub inline fn loadBMP(al: *Allocator, path: []const u8) !Texture {
    const data = try std.fs.cwd().readFileAlloc(al, path, 1024 * 1024 * 128);
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

/// Return a texture from a TGA data. Memory must be freed by the caller
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

/// Load a TGA texture. Memory must be freed by the caller
pub fn loadTGA(al: *Allocator, path: []const u8) !Texture {
    const file_data = try std.fs.cwd().readFileAlloc(al, path, 1024 * 1024 * 128);
    defer al.free(file_data);
    
    return try textureFromTgaData(al, file_data);
}

/// The bitmap font texture is a 16x16 ascii characters
/// The font size x and y is the character size in pixels on the texture
pub const BitmapFont = struct {
    texture: Texture,
    font_size_x: u32,
    font_size_y: u32,
    character_spacing: u32,
};

pub const Mesh = struct {
    v: []Vertex,
    i: []u32,
    texture: Texture,
};

pub const TextureMode = enum {
    Strech,
    Tile,
};

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


/// Converts screen coordinates (-1, 1) to pixel coordinates (0, screen size)
pub inline fn screenToPixel(sc: f32, screen_size: u32) i32 {
    return @floatToInt(i32, (sc + 1.0) * 0.5 * @intToFloat(f32, screen_size));
}

pub const Buffer = struct {
    width: u32,
    height: u32,
    screen: []u8,
    depth: []f32,
    
    pub fn allocate(b: *Buffer, al: *Allocator, width: u32, height: u32) !void {
        b.screen = try al.alloc(u8, width * height * 4);
        errdefer al.free(b.screen);
        
        b.depth = try al.alloc(f32, width * height);
        errdefer al.free(b.depth);
        
        b.width = width;
        b.height = height;
    }
    
    pub fn free(b: *Buffer, al: *Allocator) void {
        al.free(b.screen);
        al.free(b.depth);
    }
    
    pub fn resize(b: *Buffer, al: *Allocator, width: u32, height: u32) !void {
        b.screen = try al.realloc(b.screen, width * height * 4);
        errdefer al.free(b.screen);
        
        b.depth = try al.realloc(b.depth, width * height);
        errdefer al.free(b.depth);
        
        b.width = width;
        b.height = height;
    }
    
    /// Draw a single pixel to the screen
    pub inline fn putPixel(b: Buffer, xi: i32, yi: i32, color: Color) void {
        if (xi > b.width - 1) return;
        if (yi > b.height - 1) return;
        if (xi < 0) return;
        if (yi < 0) return;
        
        const x = @intCast(u32, xi);
        const y = @intCast(u32, yi);
        
        const pixel = b.screen[ (x + y * b.width) * 4 ..][0..3];
        
        // TODO: Alpha blending
        if (color.a > 0.999) {
            pixel[0] = @floatToInt(u8, color.b * 255);
            pixel[1] = @floatToInt(u8, color.g * 255);
            pixel[2] = @floatToInt(u8, color.r * 255);
        }
    }
    
    /// Draw a pixel on the screen using RGBA colors
    pub inline fn putPixelRGBA(buf: Buffer, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        if (x > buf.width - 1) return;
        if (y > buf.height - 1) return;
        if (x < 0) return;
        if (y < 0) return;
        
        const pixel = buf.screen[(x + y * buf.width) * 4 ..][0..3];
        // TODO: Alpha blending
        if (a > 0) {
            pixel[0] = r;
            pixel[1] = g;
            pixel[2] = b;
        }
    }
    
    /// Draw a solid colored circle on the screen
    pub fn fillCircle(b: Buffer, x: i32, y: i32, d: u32, color: Color) void {
        const r = (d / 2) + 1;
        var v: i32 = -@intCast(i32, r);
        while (v <= r) : (v += 1) {
            var u: i32 = -@intCast(i32, r);
            while (u <= r) : (u += 1) {
                if (u * u + v * v < (d * d / 4)) {
                    putPixel(b, x + u, y + v, color);
                }
            }
        }
    }
    
    var print_buff: [512]u8 = undefined;
    
    /// Draw a formated text on the screen
    pub fn drawBitmapFontFmt(b: Buffer, comptime fmt: []const u8, args: anytype, x: u32, y: u32, scale_x: u32, scale_y: u32, font: BitmapFont) void {
        const fpst = std.fmt.bufPrint(&print_buff, fmt, args) catch {
            drawBitmapFont(b, "text to long", x, y, scale_x, scale_y, font);
            return;
        };
        drawBitmapFont(b, fpst, x, y, scale_x, scale_y, font);
    }
    
    /// Draw a text on the screen
    pub fn drawBitmapFont(b: Buffer, text: []const u8, x: u32, y: u32, scale_x: u32, scale_y: u32, font: BitmapFont) void {
        for (text) |t, i| {
            const char_index: u32 = t;
            const fx = char_index % 16 * font.font_size_x;
            const fy = char_index / 16 * font.font_size_y;
            
            const x_pos = x + @intCast(u32, i) * scale_x * font.character_spacing;
            drawBitmapChar(b, t, x_pos, y, scale_x, scale_y, font);
        }
    }
    
    /// Draw a character on the screen
    pub fn drawBitmapChar(b: Buffer, char: u8, x: u32, y: u32, scale_x: u32, scale_y: u32, font: BitmapFont) void {
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
                        putPixelRGBA(b, x_pos, y_pos, color[0], color[1], color[2], color[3]);
                    }
                }
            }
        }
    }
    
    /// draw a filled rectangle
    pub fn fillRect(b: Buffer, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        // Clamp values
        const max_x = @intCast(i32, b.width);
        const max_y = @intCast(i32, b.height);
        
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
                putPixel(b, x_i, y_i, color);
            }
        }
    }
    
    /// Draw a texture on the screen, the texture can be resized
    pub fn drawTexture(b: Buffer, x: i32, y: i32, w: u32, h: u32, tex: Texture) void {
        const max_x = @intCast(i32, b.width);
        const max_y = @intCast(i32, b.height);
        
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
                const buffer_i = 4 * (screen_x + screen_y * b.width);
                const pixel = b.screen[buffer_i..];
                
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
    
    /// Blit texture on screen, does not change the size of the texture
    pub fn blitTexture(b: Buffer, x: i32, y: i32, tex: Texture) void {
        // Clamp values
        const max_x = @intCast(i32, b.width);
        const max_y = @intCast(i32, b.height);
        
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
            const buffer_i = 4 * (x1 + screen_y * b.width);
            const pixel = b.screen[buffer_i..];
            
            @memcpy(pixel.ptr, tex_pixel.ptr, 4 * (x2 - x1));
            
            texture_y += 1;
        }
    }
    
    /// draw a hollow rectangle
    pub fn drawRect(b: Buffer, x: i32, y: i32, w: u32, h: u32, color: Color) void {
        const width = @intCast(i32, std.math.clamp(w, 0, b.width)) - x;
        const height = @intCast(i32, std.math.clamp(h, 0, b.height)) - y;
        
        const max_x = @intCast(i32, b.width);
        const max_y = @intCast(i32, b.height);
        
        const x1 = std.math.clamp(x, 0, max_x);
        const y1 = std.math.clamp(y, 0, max_y);
        
        const sx2 = @intCast(i32, w) + x;
        const sy2 = @intCast(i32, h) + y;
        
        const x2 = std.math.clamp(sx2, 0, max_x);
        const y2 = std.math.clamp(sy2, 0, max_y);
        
        if (x2 == 0 or y2 == 0) return;
        
        var xi: i32 = x1;
        while (xi < x2) : (xi += 1) {
            putPixel(b, xi, y1, color);
            putPixel(b, xi, y2 - 1, color);
        }
        
        var yi: i32 = y1;
        while (yi < y2) : (yi += 1) {
            putPixel(b, x1, yi, color);
            putPixel(b, x2 - 1, yi, color);
        }
    }
    
    /// draw a line with a width of 1 pixel
    pub fn drawLine(b: Buffer, xa: i32, ya: i32, xb: i32, yb: i32, color: Color) void {
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
                putPixel(b, @floatToInt(i32, x), y, color);
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
                putPixel(b, x, @floatToInt(i32, y), color);
                y += dy;
            }
        }
    }
    
    /// Draw a line with a width defined by line_width
    pub fn drawLineWidth(b: Buffer, xa: i32, ya: i32, xb: i32, yb: i32, color: Color, line_width: u32) void {
        if (line_width == 1) {
            drawLine(b, xa, ya, xb, yb, color);
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
                fillCircle(b, @floatToInt(i32, x), y, line_width, color);
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
                fillCircle(b, x, @floatToInt(i32, y), line_width / 2, color);
                y += dy;
            }
        }
    }
    
    /// Fill the screen with a RGB color
    pub fn fillScreenWithRGBColor(buf: Buffer, r: u8, g: u8, b: u8) void {
        var index: usize = 0;
        while (index < buf.screen.len) : (index += 4) {
            buf.screen[index] = b;
            buf.screen[index + 1] = g;
            buf.screen[index + 2] = r;
        }
    }
    
    /// Draw a triangle
    pub inline fn drawTriangle(b: Buffer, xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32, color: Color, line_width: u32) void {
        drawLineWidth(b, xa, ya, xb, yb, color, line_width);
        drawLineWidth(b, xb, yb, xc, yc, color, line_width);
        drawLineWidth(b, xc, yc, xa, ya, color, line_width);
    }
    
    /// Draw a solid triangle
    pub fn fillTriangle(b: Buffer, xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32, color: Color) void {
        const x_left = math.min(math.min(xa, xb), math.max(xc, 0));
        const x_right = math.max(math.max(xa, xb), math.min(xc, @intCast(i32, b.width)));
        const y_up = math.min(math.min(ya, yb), math.max(yc, 0));
        const y_down = math.max(math.max(ya, yb), math.min(yc, @intCast(i32, b.height)));
        
        var y: i32 = y_up;
        while (y < y_down) : (y += 1) {
            var x: i32 = x_left;
            while (x < x_right) : (x += 1) {
                var w0 = edgeFunctionI(xb, yb, xc, yc, x, y);
                var w1 = edgeFunctionI(xc, yc, xa, ya, x, y);
                var w2 = edgeFunctionI(xa, ya, xb, yb, x, y);
                
                if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                    putPixel(b, x, y, color);
                }
            }
        }
    }
    
    // ==== 3d renderer ====
    
    /// Raster a triangle
    pub fn rasterTriangle(b: Buffer, triangle: [3]Vertex, texture: Texture, face_lighting: f32) void {
        @setFloatMode(.Optimized);
        
        const v_size = 4;
        
        const face_lighting_i = @floatToInt(u16, face_lighting * 255);
        
        const xa = screenToPixel(triangle[0].pos.x, b.width);
        const xb = screenToPixel(triangle[1].pos.x, b.width);
        const xc = screenToPixel(triangle[2].pos.x, b.width);
        
        const ya = screenToPixel(-triangle[0].pos.y, b.height);
        const yb = screenToPixel(-triangle[1].pos.y, b.height);
        const yc = screenToPixel(-triangle[2].pos.y, b.height);
        
        const x_left = math.max(math.min(math.min(xa, xb), xc), 0);
        const x_right = math.min(math.max(math.max(xa, xb), xc), @intCast(i32, b.width - 1));
        const y_up = math.max(math.min(math.min(ya, yb), yc), 0);
        const y_down = math.min(math.max(math.max(ya, yb), yc), @intCast(i32, b.height - 1));
        
        const w0_a = @intToFloat(f32, yc - yb);
        const w1_a = @intToFloat(f32, ya - yc);
        const area = @intToFloat(f32, edgeFunctionI(xa, ya, xb, yb, xc, yc));
        
        if (area < 0.0001 and area > -0.0001) return;
        
        const w0_a_v = @splat(v_size, w0_a);
        const w1_a_v = @splat(v_size, w1_a);
        const area_v = @splat(v_size, area);
        const one_v = @splat(v_size, @as(f32, 1.0));
        const zero_v = @splat(v_size, @as(f32, 0.0));
        const inc_v: std.meta.Vector(v_size, f32) = blk: {
            var v = @splat(v_size, @as(f32, 0.0));
            var i: u32 = 0;
            while (i < v_size) : (i += 1) v[i] = @intToFloat(f32, i);
            break :blk v;
        };
        const false_v = @splat(v_size, @as(bool, false));
        
        const xb_v = @splat(v_size, @intToFloat(f32, xb));
        const xc_v = @splat(v_size, @intToFloat(f32, xc));
        
        const tri0_w_v = @splat(v_size, triangle[0].w);
        const tri1_w_v = @splat(v_size, triangle[1].w);
        const tri2_w_v = @splat(v_size, triangle[2].w);
        
        const tri0_u_v = @splat(v_size, triangle[0].uv.x);
        const tri1_u_v = @splat(v_size, triangle[1].uv.x);
        const tri2_u_v = @splat(v_size, triangle[2].uv.x);
        
        const tri0_v_v = @splat(v_size, triangle[0].uv.y);
        const tri1_v_v = @splat(v_size, triangle[1].uv.y);
        const tri2_v_v = @splat(v_size, triangle[2].uv.y);
        
        const tex_width_v = @splat(v_size, @intToFloat(f32, texture.width));
        const tex_height_v = @splat(v_size, @intToFloat(f32, texture.height));
        
        var y: i32 = y_up;
        while (y <= y_down) : (y += 1) {
            var x: i32 = x_left;
            const db_iy = y * @intCast(i32, b.width);
            
            const w0_b = @intToFloat(f32, (y -% yb) *% (xc -% xb));
            const w1_b = @intToFloat(f32, (y -% yc) *% (xa -% xc));
            
            const w0_b_v = @splat(v_size, w0_b);
            const w1_b_v = @splat(v_size, w1_b);
            
            while (x <= x_right) {
                const x_v = @splat(v_size, @intToFloat(f32, x)) + inc_v;
                var w0_v = ((x_v - xb_v) * w0_a_v - w0_b_v) / area_v;
                var w1_v = ((x_v - xc_v) * w1_a_v - w1_b_v) / area_v;
                var w2_v = one_v - w1_v - w0_v;
                
                const w0_cmp_v = w0_v < zero_v;
                const w1_cmp_v = w1_v < zero_v;
                const w2_cmp_v = w2_v < zero_v;
                
                if (@reduce(.And, w0_cmp_v)) {
                    x += v_size;
                    continue;
                }
                if (@reduce(.And, w1_cmp_v)) {
                    x += v_size;
                    continue;
                }
                
                if (@reduce(.And, w2_cmp_v)) {
                    x += v_size;
                    continue;
                }
                
                w0_v /= tri0_w_v;
                w1_v /= tri1_w_v;
                w2_v /= tri2_w_v;
                const w_sum = w0_v + w1_v + w2_v;
                
                if (@reduce(.Or, w_sum == zero_v)) {
                    x += v_size;
                    continue;
                }
                
                w0_v /= w_sum;
                w1_v /= w_sum;
                w2_v /= w_sum;
                
                var db_i = @intCast(u32, x + db_iy);
                db_i = math.min(db_i, b.width * b.height - v_size);
                
                var depth_slice = b.depth[db_i..][0..v_size];
                const depth_v: std.meta.Vector(v_size, f32) = depth_slice.*;
                
                const z_v = tri0_w_v * w0_v + tri1_w_v * w1_v + tri2_w_v * w2_v;
                const z_mask_v = depth_v < z_v;
                
                if (@reduce(.And, z_mask_v)) {
                    x += v_size;
                    continue;
                }
                
                var u_v = tri0_u_v * w0_v + tri1_u_v * w1_v + tri2_u_v * w2_v;
                var v_v = tri0_v_v * w0_v + tri1_v_v * w1_v + tri2_v_v * w2_v;
                
                u_v *= tex_width_v;
                v_v *= tex_height_v;
                
                var i: u32 = 0;
                while (i < v_size and x < b.width) : (i += 1) {
                    var w0 = w0_v[i];
                    var w1 = w1_v[i];
                    var w2 = w2_v[i];
                    
                    if (!(w0_cmp_v[i] or w1_cmp_v[i] or w2_cmp_v[i])) {
                        const z = z_v[i];
                        if (!z_mask_v[i]) {
                            depth_slice[i] = z;
                            
                            var color = Color{};
                            
                            const tex_u = @intCast(usize, @mod(@floatToInt(i32, u_v[i]), @intCast(i32, texture.width)));
                            const tex_v = @intCast(usize, @mod(@floatToInt(i32, v_v[i]), @intCast(i32, texture.height)));
                            
                            const tex_pos = (tex_u + tex_v * texture.width) * 4;
                            var tpixel = texture.raw[tex_pos..][0..4].*;
                            
                            tpixel[0] = @intCast(u8, tpixel[0] * face_lighting_i / 255);
                            tpixel[1] = @intCast(u8, tpixel[1] * face_lighting_i / 255);
                            tpixel[2] = @intCast(u8, tpixel[2] * face_lighting_i / 255);
                            
                            const pixel_pos = @intCast(u32, x + y * @intCast(i32, b.width)) * 4;
                            const pixel = b.screen[pixel_pos..][0..4];
                            
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
    
    pub fn drawMesh(b: Buffer, mesh: Mesh, mode: RasterMode, cam: Camera3D, transform: Transform) void {
        
        const hw_ratio = @intToFloat(f32, b.height) /
            @intToFloat(f32, b.width);
        const proj_matrix = perspectiveMatrix(cam.near, cam.far, cam.fov, hw_ratio);
        
        var index: u32 = 0;
        main_loop: while (index < mesh.i.len - 2) : (index += 3) {
            const ia = mesh.i[index];
            const ib = mesh.i[index + 1];
            const ic = mesh.i[index + 2];
            
            var triangle = [_]Vertex{ mesh.v[ia], mesh.v[ib], mesh.v[ic] };
            
            // World Trasform
            {
                var i: u32 = 0;
                while (i < 3) : (i += 1) {
                    triangle[i].pos = Vec3_add(triangle[i].pos, transform.position);
                }
            }
            
            
            // Calculate normal
            var n = Vec3{};
            {
                const t1 = Vec3_sub(triangle[1].pos, triangle[0].pos);
                const t2 = Vec3_sub(triangle[2].pos, triangle[0].pos);
                n = Vec3_normalize(Vec3_cross(t1, t2));
            }
            
            const face_normal_dir = Vec3_dot(n, Vec3_sub(triangle[0].pos, cam.pos));
            if (face_normal_dir > 0.0) continue;
            
            // Lighting
            var face_lighting: f32 = 1.0;
            {
                var ld = Vec3_normalize(Vec3.c(0.5, -2.0, 1.0));
                
                face_lighting = Vec3_dot(ld, n.neg());
                if (face_lighting < 0.1) face_lighting = 0.1;
            }
            
            var triangle_l: [8][3]Vertex = undefined;
            var triangle_l_len: u32 = 1;
            triangle_l[0] = triangle;
            
            // Camera Trasform
            {
                var i: u32 = 0;
                while (i < 3) : (i += 1) {
                    triangle_l[0][i].pos = Vec3_sub(triangle_l[0][i].pos, cam.pos);
                    
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
                        const pixel_size_y = 1.0 / @intToFloat(f32, b.height);
                        const pixel_size_x = 1.0 / @intToFloat(f32, b.width);
                        
                        const xa = screenToPixel(triangle[0].pos.x, b.width);
                        const xb = screenToPixel(triangle[1].pos.x, b.width);
                        const xc = screenToPixel(triangle[2].pos.x, b.width);
                        
                        const ya = screenToPixel(-triangle[0].pos.y, b.height);
                        const yb = screenToPixel(-triangle[1].pos.y, b.height);
                        const yc = screenToPixel(-triangle[2].pos.y, b.height);
                        
                        if (mode == .Points) {
                            fillCircle(b, xa, ya, 5, Color.c(1, 1, 1, 1));
                            fillCircle(b, xb, yb, 5, Color.c(1, 1, 1, 1));
                            fillCircle(b, xc, yc, 5, Color.c(1, 1, 1, 1));
                        } else if (mode == .Lines) {
                            const line_color = Color.c(1, 1, 1, 1);
                            drawTriangle(b, xa, ya, xb, yb, xc, yc, line_color, 1);
                        }
                    },
                    .NoShadow => {
                        rasterTriangle(b, triangle, mesh.texture, 1.0);
                    },
                    .Texture => {
                        rasterTriangle(b, triangle, mesh.texture, face_lighting);
                    },
                }
            }
        }
    }
};

/// Return a cube mesh
pub fn cubeMesh(al: *Allocator) Mesh {
    var cube_v = [_]Vertex{
        Vertex.c(Vec3.c(-0.5, 0.5, 0.5), Vec2.c(0, 1)),
        Vertex.c(Vec3.c(0.5, 0.5, 0.5), Vec2.c(1, 1)),
        Vertex.c(Vec3.c(-0.5, -0.5, 0.5), Vec2.c(0, 0)),
        Vertex.c(Vec3.c(0.5, -0.5, 0.5), Vec2.c(1, 0)),
        
        Vertex.c(Vec3.c(-0.5, 0.5, -0.5), Vec2.c(1, 1)),
        Vertex.c(Vec3.c(0.5, 0.5, -0.5), Vec2.c(0, 1)),
        Vertex.c(Vec3.c(-0.5, -0.5, -0.5), Vec2.c(1, 0)),
        Vertex.c(Vec3.c(0.5, -0.5, -0.5), Vec2.c(0, 0)),
        
        
        // top
        Vertex.c(Vec3.c(-0.5, 0.5, 0.5), Vec2.c(0, 0)),
        Vertex.c(Vec3.c(0.5, 0.5, 0.5), Vec2.c(1, 0)),
        Vertex.c(Vec3.c(-0.5, -0.5, 0.5), Vec2.c(0, 1)),
        Vertex.c(Vec3.c(0.5, -0.5, 0.5), Vec2.c(1, 1)),
        
        Vertex.c(Vec3.c(-0.5, 0.5, -0.5), Vec2.c(0, 1)),
        Vertex.c(Vec3.c(0.5, 0.5, -0.5), Vec2.c(1, 1)),
        Vertex.c(Vec3.c(-0.5, -0.5, -0.5), Vec2.c(0, 0)),
        Vertex.c(Vec3.c(0.5, -0.5, -0.5), Vec2.c(1, 0)),
    };
    
    var cube_i = [_]u32{
        0, 2, 3,
        0, 3, 1,
        1, 3, 7,
        1, 7, 5,
        
        4, 6, 2,
        4, 2, 0,
        5, 7, 6,
        5, 6, 4,
        
        // top
        4 + 8, 0 + 8, 1 + 8,
        4 + 8, 1 + 8, 5 + 8,
        6 + 8, 3 + 8, 2 + 8,
        6 + 8, 7 + 8, 3 + 8,
    };
    
    var cube_mesh = Mesh{
        .v = al.alloc(Vertex, cube_v.len) catch @panic("alloc error\n"),
        .i = al.alloc(u32, cube_i.len) catch @panic("alloc error\n"),
        .texture = undefined,
    };
    
    var i: u32 = 0;
    while (i < cube_v.len) : (i += 1) {
        cube_mesh.v[i] = cube_v[i];
    }
    
    i = 0;
    while (i < cube_i.len) : (i += 1) {
        cube_mesh.i[i] = cube_i[i];
    }
    
    return cube_mesh;
}


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
            v.uv.y = 1.0 - (v.pos.y + center_y) / @intToFloat(f32, size_y);
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
