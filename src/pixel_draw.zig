usingnamespace if (@import("builtin").os.tag == .windows)
@import("win32_plataform.zig")
else
@import("xlib_plataform.zig");


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

pub inline fn keyStrengh(key: Keys) f32 {
    return @intToFloat(f32, @boolToInt(keyPressed(key)));
}

pub const init = plataformInit;

pub usingnamespace @import("pixel_draw_module.zig");

/// This is only used with the plataform layer
pub var gb: Buffer = undefined;