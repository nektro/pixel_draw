const std = @import("std");
const math = std.math;


// Struct Declarations
pub const Color = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,
    
    pub inline fn c(r: f32, g: f32, b: f32, a: f32) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }
};

pub const Vec2 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    
    pub inline fn c(x: f32, y: f32) Vec2 {
        return Vec2 {.x = x, .y = y};
    }
};

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    
    pub inline fn c(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 {.x = x, .y = y, .z = z};
    }
    
    pub inline fn neg(v: *Vec3) Vec3 {
        return Vec3{.x = -v.x, .y = -v.y, .z = -v.z};
    }
};

pub const Vec4 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,
    
    pub inline fn c(x: f32, y: f32, z: f32, w: f32) Vec3 {
        return Vec3 {.x = x, .y = y, .z = z, .w = w};
    }
};

pub const Plane = struct {
    n: Vec3 = .{},
    d: f32 = .{},
    
    pub inline fn c(nx: f32, ny: f32, nz: f32, d: f32) Plane {
        return Plane{
            .n = Vec3_normalize(Vec3.c(nx, ny, nz)),
            .d = d,
        };
    }
};

pub const Vertex = struct {
    pos: Vec3 = .{},
    color: Color = .{},
    uv: Vec2 = .{},
    w: f32 = 1.0,
    
    pub inline fn c(pos: Vec3, color: Color, uv: Vec2) Vertex {
        return Vertex{.pos = pos, .color = color, .uv = uv};
    }
};

pub fn Vec3_add(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x + vb.x,
        .y = va.y + vb.y,
        .z = va.z + vb.z
    };
    return result;
}

pub fn Vec3_sub(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x - vb.x,
        .y = va.y - vb.y,
        .z = va.z - vb.z
    };
    return result;
}

pub fn Vec3_mul(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x * vb.x,
        .y = va.y * vb.y,
        .z = va.z * vb.z
    };
    return result;
}

pub fn Vec3_div(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x / vb.x,
        .y = va.y / vb.y,
        .z = va.z / vb.z
    };
    return result;
}

pub fn Vec3_add_F(v: Vec3, f: f32) Vec3 {
    const result = Vec3{
        .x = v.x + f,
        .y = v.y + f,
        .z = v.z + f,
    };
    return result;
}

pub fn Vec3_sub_F(v: Vec3, f: f32) Vec3 {
    const result = Vec3{
        .x = v.x - f,
        .y = v.y - f,
        .z = v.z - f,
    };
    return result;
}

pub fn Vec3_mul_F(v: Vec3, f: f32) Vec3 {
    const result = Vec3{
        .x = v.x * f,
        .y = v.y * f,
        .z = v.z * f,
    };
    return result;
}

pub fn Vec3_div_F(v: Vec3, f: f32) Vec3 {
    const result = Vec3{
        .x = v.x / f,
        .y = v.y / f,
        .z = v.z / f,
    };
    return result;
}

pub fn Vec3_dot(va: Vec3, vb: Vec3) f32 {
    const result = va.x * vb.x + va.y * vb.y + va.z * vb.z; 
    return result;
}

pub fn Vec3_cross(va: Vec3, vb: Vec3) Vec3 {
    var result = Vec3{};
    result.x = va.y*vb.z - va.z*vb.y;
    result.y = va.z*vb.x - va.x*vb.z;
    result.z = va.x*vb.y - va.y*vb.x;
    return result;
}

pub fn Vec3_len(v: Vec3) f32 {
    const result = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
    return result;
}

pub fn Vec3_normalize(v: Vec3) Vec3 {
    const result = Vec3_div_F(v, Vec3_len(v));
    return result;
}

pub fn lineIntersectPlane(l_origin: Vec3, l_dir: Vec3, plane: Plane) ?Vec3
{
    var result: ?Vec3 = null;
    
    const denom = Vec3_dot(plane.n, l_dir);
    const epslon = 0.001;
    if (denom > epslon or denom < -epslon) {
        const t = (-plane.d - Vec3_dot(plane.n, l_origin)) / denom;
        const hit_pos = Vec3_add(l_origin, Vec3_mul_F(l_dir, t));
        result = hit_pos;
    }
    
    return result;
}


pub const Bivec3 = struct {
    xy: f32,
    xz: f32,
    yz: f32,
};
