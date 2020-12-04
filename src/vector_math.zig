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
        return Vec2{ .x = x, .y = y };
    }
};

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    
    pub inline fn c(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }
    
    pub inline fn neg(v: *Vec3) Vec3 {
        return Vec3{ .x = -v.x, .y = -v.y, .z = -v.z };
    }
};

pub const Vec4 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,
    
    pub inline fn c(x: f32, y: f32, z: f32, w: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z, .w = w };
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
    uv: Vec2 = .{},
    w: f32 = 1.0,
    
    pub inline fn c(pos: Vec3, uv: Vec2) Vertex {
        return Vertex{
            .pos = pos,
            .uv = uv,
        };
    }
};

pub const Transform = struct {
    position: Vec3 = .{},
    rotation: Vec3 = .{}, // TODO(Samuel): Change to rotor
    scale: Vec3 = .{
        .x = 1,
        .y = 1,
        .z = 1,
    },
};

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    const result = (1 - t) * a + t * b;
    return result;
}

pub fn Color_lerp(ca: Color, cb: Color, t: f32) Color {
    const result = Color{
        .r = lerp(ca.r, cb.r, t),
        .g = lerp(ca.g, cb.g, t),
        .b = lerp(ca.b, cb.b, t),
        .a = lerp(ca.a, cb.a, t),
    };
    return result;
}

pub fn Vec3_add(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x + vb.x,
        .y = va.y + vb.y,
        .z = va.z + vb.z,
    };
    return result;
}

pub fn Vec3_sub(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x - vb.x,
        .y = va.y - vb.y,
        .z = va.z - vb.z,
    };
    return result;
}

pub fn Vec3_mul(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x * vb.x,
        .y = va.y * vb.y,
        .z = va.z * vb.z,
    };
    return result;
}

pub fn Vec3_div(va: Vec3, vb: Vec3) Vec3 {
    const result = Vec3{
        .x = va.x / vb.x,
        .y = va.y / vb.y,
        .z = va.z / vb.z,
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
    result.x = va.y * vb.z - va.z * vb.y;
    result.y = va.z * vb.x - va.x * vb.z;
    result.z = va.x * vb.y - va.y * vb.x;
    return result;
}

pub fn Vec3_len(v: Vec3) f32 {
    const result = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return result;
}

pub fn Vec3_normalize(v: Vec3) Vec3 {
    const l = Vec3_len(v);
    const result = if (l > 0.001) Vec3_div_F(v, Vec3_len(v)) else Vec3{};
    return result;
}

pub fn lineIntersectPlane(l_origin: Vec3, l_dir: Vec3, plane: Plane) ?Vec3 {
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

pub fn lineIntersectPlaneT(l_origin: Vec3, l_end: Vec3, plane: Plane, t: *f32) Vec3 {
    const ad = Vec3_dot(l_origin, plane.n);
    const bd = Vec3_dot(l_end, plane.n);
    t.* = (-plane.d - ad) / (bd - ad);
    const line_start_to_end = Vec3_sub(l_end, l_origin);
    const line_to_intersect = Vec3_mul_F(line_start_to_end, t.*);
    return Vec3_add(l_origin, line_to_intersect);
}

pub const Bivec3 = struct {
    xy: f32,
    xz: f32,
    yz: f32,
};

pub inline fn edgeFunction(xa: f32, ya: f32, xb: f32, yb: f32, xc: f32, yc: f32) f32 {
    return (xc - xa) * (yb - ya) - (yc - ya) * (xb - xa);
}

pub inline fn edgeFunctionI(xa: i32, ya: i32, xb: i32, yb: i32, xc: i32, yc: i32) i32 {
    const result = (xc -% xa) *% (yb -% ya) -% (yc -% ya) *% (xb -% xa);
    return result;
}

pub fn interpolateVertexAttr(va: Vertex, vb: Vertex, vc: Vertex, pos: Vec3) Vertex {
    var result = Vertex{
        .pos = pos,
    };
    
    const area = edgeFunction(va.pos.x, va.pos.y, vb.pos.x, vb.pos.y, vc.pos.x, vc.pos.y);
    
    var w0 = edgeFunction(vb.pos.x, vb.pos.y, vc.pos.x, vc.pos.y, pos.x, pos.y) / area;
    
    var w1 = edgeFunction(vc.pos.x, vc.pos.y, va.pos.x, va.pos.y, pos.x, pos.y) / area;
    var w2 = 1.0 - w0 - w1;
    
    if (false) {
        w0 /= va.w;
        w1 /= va.w;
        w2 /= va.w;
        const w_sum = w0 + w1 + w2;
        w0 /= w_sum;
        w1 /= w_sum;
        w2 /= w_sum;
    }
    
    result.color.r = w0 * va.color.r + w1 * vb.color.r + w2 * vc.color.r;
    result.color.g = w0 * va.color.g + w1 * vb.color.g + w2 * vc.color.g;
    result.color.b = w0 * va.color.b + w1 * vb.color.b + w2 * vc.color.b;
    result.color.a = w0 * va.color.a + w1 * vb.color.a + w2 * vc.color.a;
    
    return result;
}

pub fn baricentricCoordinates(a: anytype, b: anytype, c: anytype, p: anytype) Vec3 {
    if (@TypeOf(a) != Vec3 and @TypeOf(a) != Vec2) @compileError("");
    if (@TypeOf(b) != Vec3 and @TypeOf(b) != Vec2) @compileError("");
    if (@TypeOf(c) != Vec3 and @TypeOf(c) != Vec2) @compileError("");
    if (@TypeOf(p) != Vec3 and @TypeOf(p) != Vec2) @compileError("");
    
    const area = edgeFunction(a.x, a.y, b.x, b.y, c.x, c.y);
    var w0 = edgeFunction(b.x, b.y, c.x, c.y, p.x, p.y) / area;
    var w1 = edgeFunction(c.x, c.y, a.x, a.y, p.x, p.y) / area;
    var w2 = 1.0 - w0 - w1;
    return Vec3.c(w0, w1, w2);
}

pub fn rotateVectorOnY(v: Vec3, angle: f32) Vec3 {
    const result = Vec3{
        .x = v.x * @cos(angle) + v.z * @sin(angle),
        .y = v.y,
        .z = -v.x * @sin(angle) + v.z * @cos(angle),
    };
    return result;
}

pub fn rotateVectorOnX(v: Vec3, angle: f32) Vec3 {
    const result = Vec3{
        .x = v.x,
        .y = v.y * @cos(angle) + v.z * @sin(angle),
        .z = -v.y * @sin(angle) + v.z * @cos(angle),
    };
    return result;
}

pub fn rotateVectorOnZ(v: Vec3, angle: f32) Vec3 {
    const result = Vec3{
        .x = v.x * @cos(angle) + v.y * @sin(angle),
        .y = -v.x * @sin(angle) + v.y * @cos(angle),
        .z = v.z,
    };
    return result;
}

pub fn perspectiveMatrix(near: f32, far: f32, fov: f32, height_to_width_ratio: f32) [4][4]f32 {
    const S: f32 = 1 / (std.math.tan(fov * 3.1415926535 / 90.0));
    var matrix = [4][4]f32{
        .{ -S * height_to_width_ratio, 0, 0, 0 },
        .{ 0, -S, 0, 0 },
        .{ 0, 0, -(far / (far - near)), -(far * near / (far - near)) },
        .{ 0, 0, -1, 0 },
    };
    return matrix;
}

pub fn eulerAnglesToDirVector(v: Vec3) Vec3 {
    var result = Vec3{
        .x = -@sin(v.y),
        .y = -@sin(v.x) * @cos(v.y),
        .z = @cos(v.x) * @cos(v.y),
    };
    return result;
}

pub fn sphericalToCartesian(r: f32, z: f32, a: f32) Vec3 {
    const result = Vec3{
        .x = r * @sin(z) * @cos(a),
        .y = r * @sin(z) * @sin(a),
        .z = r * @cos(z),
    };
    return result;
}