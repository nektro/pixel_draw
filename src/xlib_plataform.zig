const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cDefine("XUTIL_DEFINE_FUNCTIONS", ""); // replace macros with functions
    @cInclude("X11/Xutil.h");
    // @cInclude("X11/Xatom.h");
});

const std = @import("std");
const draw = @import("pixel_draw.zig");

var main_allocator: *std.mem.Allocator = undefined;

// ===== Input =====
pub var mouse_pos_x: i32 = 0;
pub var mouse_pos_y: i32 = 0;
pub var is_mouse_on_window: bool = false;

pub var mouse_buttons_down = [_]bool{false} ** 8;
pub var mouse_buttons_up = [_]bool{false} ** 8;
pub var mouse_buttons_pressed = [_]bool{false} ** 8;

const keymap = [_]u32{
    c.XK_q,
    c.XK_w,
    c.XK_e,
    c.XK_r,
    c.XK_a,
    c.XK_s,
    c.XK_d,
    c.XK_1,
    c.XK_2,
    c.XK_3,
    c.XK_4,
    c.XK_5,
    c.XK_6,
    c.XK_7,
    c.XK_8,
    c.XK_9,
    c.XK_0,
    c.XK_Up,
    c.XK_Down,
    c.XK_Left,
    c.XK_Right,
};

pub var keys_down = [_]bool{false} ** keymap.len;
pub var keys_up = [_]bool{false} ** keymap.len;
pub var keys_pressed = [_]bool{false} ** keymap.len;

pub var char_input_buffer: [4096]u8 = undefined;
pub var char_input_len: usize = 0;

// =================

pub fn plataformInit(
    al: *std.mem.Allocator,
    w_width: u32,
    w_height: u32,
    start_fn: fn () void,
    update_fn: fn (f32) void,
) !void {
    main_allocator = al;
    draw.gb.width = w_width;
    draw.gb.height = w_height;

    const display = blk: {
        if (c.XOpenDisplay(0)) |d| {
            break :blk d;
        } else {
            return error.NoDisplayAvailable;
        }
    };

    const root_window = c.XDefaultRootWindow(display);
    const default_screen = c.XDefaultScreen(display);

    const screen_bit_depth = 24;
    var visual_info: c.XVisualInfo = undefined;
    if (c.XMatchVisualInfo(display, default_screen, screen_bit_depth, c.TrueColor, &visual_info) == 0) {
        return error.NoMatchingVisualInfo;
    }

    var window_attr: c.XSetWindowAttributes = undefined;
    window_attr.bit_gravity = c.StaticGravity;
    window_attr.background_pixel = 0;
    window_attr.colormap = c.XCreateColormap(display, root_window, visual_info.visual, c.AllocNone);
    window_attr.event_mask = c.StructureNotifyMask | c.KeyPressMask |
        c.KeyReleaseMask | c.ButtonPressMask | c.ButtonReleaseMask;

    const atrribute_mask: u64 = c.CWBitGravity | c.CWBackPixel | c.CWColormap | c.CWEventMask;

    const window = c.XCreateWindow(display, root_window, 0, 0, draw.gb.width, draw.gb.height, 0, visual_info.depth, c.InputOutput, visual_info.visual, atrribute_mask, &window_attr);

    if (window == 0) return error.UnableToCreateWindow;
    if (c.XStoreName(display, window, "Hello") == 0) return error.ErrorInRenamingWindow;

    // Init X input
    if (false) {
        const x_input_method = c.XOpenIM(display, null, 0, 0);
        if (x_input_method == null) {
            return error.InputMethodCouldNotBeOpened;
        }

        var styles: ?*c.XIMStyles = null;
        if (c.XGetIMValues(x_input_method, c.XNQueryInputStyle, &styles) == 0 or styles == null) {
            return error.InputStylesCouldNotBeRetrived;
        }

        var best_match_style: c.XIMStyle = 0;
        var i: usize = 0;
        while (i < styles.?.count_styles) : (i += 1) {
            const this_style = styles.?.supported_styles[i];
            if (this_style == (c.XIMPreeditNothing | c.XIMStatusNothing)) {
                best_match_style = this_style;
                break;
            }
        }

        _ = c.XFree(styles);
    }

    if (c.XMapWindow(display, window) == 0) return error.ErrorMappingTheWindow;
    if (c.XFlush(display) == 0) return error.ErrorFlushinTheDisplay;

    var wm_delete_window = c.XInternAtom(display, "WM_DELETE_WINDOW", c.False);
    if (c.XSetWMProtocols(display, window, &wm_delete_window, 1) == 0)
        return error.CouldNotRegisterWmDeleteWindowProperty;

    // Setup window buffer
    const pixel_bits = 32;
    const pixel_bytes = pixel_bits / 8;
    try draw.gb.allocate(main_allocator, draw.gb.width, draw.gb.height);

    var x_window_buffer = c.XCreateImage(display, visual_info.visual, @intCast(c_uint, visual_info.depth), c.ZPixmap, 0, draw.gb.screen.ptr, draw.gb.width, draw.gb.height, pixel_bits, 0);

    var default_graphics_context = c.XDefaultGC(display, default_screen);

    start_fn();

    // var anim_offset: u32 = 0;
    var delta: f32 = 0.0;
    var initTime: i128 = 0;

    // main looping
    var size_has_changed = false;
    var should_close = false;
    while (!should_close) {
        initTime = std.time.nanoTimestamp() - initTime;
        delta = @floatCast(f32, @intToFloat(f64, initTime) / 1000000000);
        initTime = std.time.nanoTimestamp();
        // std.debug.print("{d:0.4} {d:0.4}\n", .{ 1.0 / delta, delta });

        for (draw.gb.depth) |*it| it.* = std.math.inf_f32;

        var event: c.XEvent = undefined;

        // Reset inputs
        for (mouse_buttons_down) |*it| it.* = false;
        for (mouse_buttons_up) |*it| it.* = false;
        for (keys_down) |*it| it.* = false;
        for (keys_up) |*it| it.* = false;

        { // query pointer
            var root_x: i32 = 0;
            var root_y: i32 = 0;
            var win_x: i32 = 0;
            var win_y: i32 = 0;
            var button_mask: u32 = 0;

            var root_return: c.Window = undefined;
            var win_return: c.Window = undefined;
            _ = c.XQueryPointer(display, window, &root_return, &win_return, &root_x, &root_y, &win_x, &win_y, &button_mask);

            // if (win_return == window) {
            mouse_pos_x = @intCast(i32, win_x);
            mouse_pos_y = @intCast(i32, win_y);
            // }
        }

        // Event loop
        while (c.XPending(display) > 0) {
            _ = c.XNextEvent(display, &event);
            switch (event.@"type") {
                c.DestroyNotify => {
                    const e = @ptrCast(*c.XDestroyWindowEvent, &event);
                    if (e.window == window) should_close = true;
                },

                c.ClientMessage => {
                    const e = @ptrCast(*c.XClientMessageEvent, &event);
                    if (e.data.l[0] == wm_delete_window) {
                        // This is to avoid a anoing error message when closing the application
                        _ = c.XDestroyWindow(display, window);
                        should_close = true;
                    }
                },

                c.ConfigureNotify => {
                    const e = @ptrCast(*c.XConfigureEvent, &event);
                    const nwidth = @intCast(u32, e.width);
                    const nheight = @intCast(u32, e.height);

                    size_has_changed = true;
                    draw.gb.width = nwidth;
                    draw.gb.height = nheight;
                },

                c.KeyPress => {
                    const e = @ptrCast(*c.XKeyPressedEvent, &event);
                    const key = c.XKeycodeToKeysym(display, @intCast(u8, e.keycode), 0);

                    var char_buffer: [128]u8 = undefined;
                    var status: c.XComposeStatus = undefined;
                    char_buffer[0] = 0;
                    const char_buffer_len = @intCast(usize, c.XLookupString(e, char_buffer[0..], char_buffer.len, null, &status));

                    for (char_buffer[0..char_buffer_len]) |cr| {
                        if (char_input_len >= char_input_buffer.len) break;

                        char_input_buffer[char_input_len] = cr;
                        char_input_len += 1;
                    }

                    for (keys_down) |*it, i| {
                        if (keymap[i] == key) {
                            it.* = true;
                            keys_pressed[i] = true;
                        }
                    }
                },

                c.KeyRelease => {
                    const e = @ptrCast(*c.XKeyPressedEvent, &event);
                    const key = c.XKeycodeToKeysym(display, @intCast(u8, e.keycode), 0);
                    for (keys_up) |*it, i| {
                        if (keymap[i] == key) {
                            it.* = true;
                            keys_pressed[i] = false;
                        }
                    }
                },

                c.ButtonPress => {
                    const e = @ptrCast(*c.XButtonPressedEvent, &event);
                    if (e.button <= 7) {
                        mouse_buttons_down[@intCast(usize, e.button)] = true;
                        mouse_buttons_pressed[@intCast(usize, e.button)] = true;
                    }
                },

                c.ButtonRelease => {
                    const e = @ptrCast(*c.XButtonPressedEvent, &event);
                    if (e.button <= 7) {
                        mouse_buttons_up[@intCast(usize, e.button)] = true;
                        mouse_buttons_pressed[@intCast(usize, e.button)] = false;
                    }
                },

                else => {},
            }
        }

        // Handle resizes
        if (size_has_changed) {
            size_has_changed = false;

            // Free memory
            try draw.gb.resize(main_allocator, draw.gb.width, draw.gb.height);

            x_window_buffer = c.XCreateImage(
                display,
                visual_info.visual,
                @intCast(c_uint, visual_info.depth),
                c.ZPixmap,
                0,
                draw.gb.screen.ptr,
                draw.gb.width,
                draw.gb.height,
                pixel_bits,
                0,
            );
        }

        update_fn(delta);

        _ = c.XPutImage(display, window, default_graphics_context, x_window_buffer, 0, 0, 0, 0, draw.gb.width, draw.gb.height);
    }
    draw.gb.free(main_allocator);
}
