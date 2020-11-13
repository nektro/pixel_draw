const std = @import("std");

// === Windows definitions ====================================================
const WS_OVERLAPEDWINDOW: u64 = 0x00C00000 | 0x00080000 | 0x00040000 | 0x00020000 | 0x00010000;
const WS_VISIBLE: u64 = 00200000;
extern "user32" fn GetClientRect(hWnd: win.HWND, lpRect: *RECT) callconv(.Stdcall) c_int;
extern "user32" fn BeginPaint(hWnd: win.HWND, lpPaint: *PAINTSTRUCT) callconv(.Stdcall) c_int;
extern "user32" fn EndPaint(hWnd: win.HWND, lpPaint: *const PAINTSTRUCT) callconv(.Stdcall) c_int;
extern "gdi32" fn CreateDIBSection(hdc: win.HDC, pbmi: *const BITMAPINFO, usage: c_uint, ppvBits: ?**c_void, hSection: win.HANDLE, offset: u32) callconv(.Stdcall) c_int;
extern "gdi32" fn StretchDIBits(hdc: win.HDC, xDest: c_int, yDest: c_int, DestWidth: c_int, DestHeight: c_int, xSrc: c_int, ySrc: c_int, SrcWidth: c_int, SrcHeight: c_int, lpBits: ?*const c_void, lpbmi: ?*const c_void, iUsage: c_uint, rop: u32) callconv(.Stdcall) c_int;
extern "gdi32" fn BitBlit(hdc: win.HDC, x: c_int, y: c_int, cx: c_int, cy: c_int, hdcSrc: win.HDC, x1: c_int, y1: c_int, rop: u32) c_int;

const VirtualKeys = struct {
    pub const ABNT_C1 = 0xC1;
    pub const ABNT_C2 = 0xC2;
    pub const ADD = 0x6B;
    pub const ATTN = 0xF6;
    pub const BACK = 0x08;
    pub const CANCEL = 0x03;
    pub const CLEAR = 0x0C;
    pub const CRSEL = 0xF7;
    pub const DECIMAL = 0x6E;
    pub const DIVIDE = 0x6F;
    pub const EREOF = 0xF9;
    pub const ESCAPE = 0x1B;
    pub const EXECUTE = 0x2B;
    pub const EXSEL = 0xF8;
    pub const ICO_CLEAR = 0xE6;
    pub const ICO_HELP = 0xE3;
    pub const KEY_0 = 0x30;
    pub const KEY_1 = 0x31;
    pub const KEY_2 = 0x32;
    pub const KEY_3 = 0x33;
    pub const KEY_4 = 0x34;
    pub const KEY_5 = 0x35;
    pub const KEY_6 = 0x36;
    pub const KEY_7 = 0x37;
    pub const KEY_8 = 0x38;
    pub const KEY_9 = 0x39;
    pub const KEY_A = 0x41;
    pub const KEY_B = 0x42;
    pub const KEY_C = 0x43;
    pub const KEY_D = 0x44;
    pub const KEY_E = 0x45;
    pub const KEY_F = 0x46;
    pub const KEY_G = 0x47;
    pub const KEY_H = 0x48;
    pub const KEY_I = 0x49;
    pub const KEY_J = 0x4A;
    pub const KEY_K = 0x4B;
    pub const KEY_L = 0x4C;
    pub const KEY_M = 0x4D;
    pub const KEY_N = 0x4E;
    pub const KEY_O = 0x4F;
    pub const KEY_P = 0x50;
    pub const KEY_Q = 0x51;
    pub const KEY_R = 0x52;
    pub const KEY_S = 0x53;
    pub const KEY_T = 0x54;
    pub const KEY_U = 0x55;
    pub const KEY_V = 0x56;
    pub const KEY_W = 0x57;
    pub const KEY_X = 0x58;
    pub const KEY_Y = 0x59;
    pub const KEY_Z = 0x5A;
    pub const MULTIPLY = 0x6A;
    pub const NONAME = 0xFC;
    pub const NUMPAD0 = 0x60;
    pub const NUMPAD1 = 0x61;
    pub const NUMPAD2 = 0x62;
    pub const NUMPAD3 = 0x63;
    pub const NUMPAD4 = 0x64;
    pub const NUMPAD5 = 0x65;
    pub const NUMPAD6 = 0x66;
    pub const NUMPAD7 = 0x67;
    pub const NUMPAD8 = 0x68;
    pub const NUMPAD9 = 0x69;
    pub const OEM_1 = 0xBA;
    pub const OEM_102 = 0xE2;
    pub const OEM_2 = 0xBF;
    pub const OEM_3 = 0xC0;
    pub const OEM_4 = 0xDB;
    pub const OEM_5 = 0xDC;
    pub const OEM_6 = 0xDD;
    pub const OEM_7 = 0xDE;
    pub const OEM_8 = 0xDF;
    pub const OEM_ATTN = 0xF0;
    pub const OEM_AUTO = 0xF3;
    pub const OEM_AX = 0xE1;
    pub const OEM_BACKTAB = 0xF5;
    pub const OEM_CLEAR = 0xFE;
    pub const OEM_COMMA = 0xBC;
    pub const OEM_COPY = 0xF2;
    pub const OEM_CUSEL = 0xEF;
    pub const OEM_ENLW = 0xF4;
    pub const OEM_FINISH = 0xF1;
    pub const OEM_FJ_LOYA = 0x95;
    pub const OEM_FJ_MASSHOU = 0x93;
    pub const OEM_FJ_ROYA = 0x96;
    pub const OEM_FJ_TOUROKU = 0x94;
    pub const OEM_JUMP = 0xEA;
    pub const OEM_MINUS = 0xBD;
    pub const OEM_PA1 = 0xEB;
    pub const OEM_PA2 = 0xEC;
    pub const OEM_PA3 = 0xED;
    pub const OEM_PERIOD = 0xBE;
    pub const OEM_PLUS = 0xBB;
    pub const OEM_RESET = 0xE9;
    pub const OEM_WSCTRL = 0xEE;
    pub const PA1 = 0xFD;
    pub const PACKET = 0xE7;
    pub const PLAY = 0xFA;
    pub const PROCESSKEY = 0xE5;
    pub const RETURN = 0x0D;
    pub const SELECT = 0x29;
    pub const SEPARATOR = 0x6C;
    pub const SPACE = 0x20;
    pub const SUBTRACT = 0x6D;
    pub const TAB = 0x09;
    pub const ZOOM = 0xFB;

    //pub const DOWN = 0x25;
    //pub const LEFT = 0x26;
    //pub const UP = 0x27;
    //pub const RIGHT = 0x28;

    pub const LEFT = 0x25;
    pub const UP = 0x26;
    pub const RIGHT = 0x27;
    pub const DOWN = 0x28;
};

const RECT = extern struct {
    left: c_long,
    top: c_long,
    right: c_long,
    bottom: c_long,
};

const PAINTSTRUCT = extern struct {
    hdc: win.HDC,
    fErase: win.BOOL,
    rcPaint: RECT,
    fRestore: win.BOOL,
    fIncUpdate: win.BOOL,
    rgbReserved: [32]u8,
};

const BITMAPINFOHEADER = extern struct {
    biSize: u32,
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16,
    biBitCount: u16,
    biCompression: u32,
    biSizeImage: u32,
    biXPelsPerMeter: i32,
    biYPelsPerMeter: i32,
    biClrUsed: u32,
    biClrImportant: u32,
};

const RGBQUAD = extern struct {
    rgbBlue: u8,
    rgbGreen: u8,
    rgbReed: u8,
    rgbReserved: u8,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

const win = std.os.windows;
const usr32 = win.user32;
const WNDCLASSEXA = win.user32.WNDCLASSEXA;

// ============================================================================

pub var mouse_pos_x: i32 = 0;
pub var mouse_pos_y: i32 = 0;
pub var is_mouse_on_window: bool = false;

pub var mouse_buttons_down = [_]bool{false} ** 8;
pub var mouse_buttons_up = [_]bool{false} ** 8;
pub var mouse_buttons_pressed = [_]bool{false} ** 8;

const keymap = [_]u32{
    VirtualKeys.KEY_Q,
    VirtualKeys.KEY_W,
    VirtualKeys.KEY_E,
    VirtualKeys.KEY_R,
    VirtualKeys.KEY_A,
    VirtualKeys.KEY_S,
    VirtualKeys.KEY_D,
    VirtualKeys.KEY_1,
    VirtualKeys.KEY_2,
    VirtualKeys.KEY_3,
    VirtualKeys.KEY_4,
    VirtualKeys.KEY_5,
    VirtualKeys.KEY_6,
    VirtualKeys.KEY_7,
    VirtualKeys.KEY_8,
    VirtualKeys.KEY_9,
    VirtualKeys.KEY_0,

    VirtualKeys.UP,
    VirtualKeys.DOWN,
    VirtualKeys.LEFT,
    VirtualKeys.RIGHT,
};

pub var keys_down = [_]bool{false} ** keymap.len;
pub var keys_up = [_]bool{false} ** keymap.len;
pub var keys_pressed = [_]bool{false} ** keymap.len;

fn mainWindowCallback(window: win.HWND, message: c_uint, w_param: usize, l_param: ?*c_void) callconv(.Stdcall) ?*c_void {
    var result: ?*c_void = null;
    switch (message) {
        usr32.WM_SIZE => {
            var client_rect: RECT = undefined;
            _ = GetClientRect(window, &client_rect);
            const width = @intCast(u32, client_rect.right - client_rect.left);
            const height = @intCast(u32, client_rect.bottom - client_rect.top);
            win32ResizeDibSection(width, height);
        },

        usr32.WM_DESTROY => {
            usr32.PostQuitMessage(0);
        },

        usr32.WM_CLOSE => {
            usr32.PostQuitMessage(0);
        },

        usr32.WM_KEYDOWN => {
            const key = @intCast(u32, w_param);
            for (keys_down) |*it, i| {
                if (keymap[i] == key) {
                    it.* = true;
                    keys_pressed[i] = true;
                }
            }
        },
        usr32.WM_KEYUP => {
            const key = @intCast(u32, w_param);
            for (keys_up) |*it, i| {
                if (keymap[i] == key) {
                    it.* = true;
                    keys_pressed[i] = false;
                }
            }
        },

        else => {
            result = win.user32.DefWindowProcA(window, message, w_param, l_param);
        },
    }

    return result;
}

var bitmap_info = BITMAPINFO{
    .bmiHeader = .{
        .biSize = @sizeOf(BITMAPINFOHEADER),
        .biWidth = 0,
        .biHeight = 0,
        .biPlanes = 1,
        .biBitCount = 32,
        .biCompression = 0,
        .biSizeImage = 0,
        .biXPelsPerMeter = 0,
        .biYPelsPerMeter = 0,
        .biClrUsed = 0,
        .biClrImportant = 0,
    },
    .bmiColors = undefined,
};

fn win32ResizeDibSection(width: u32, height: u32) void {
    win_width = width;
    win_height = height;

    bitmap_info.bmiHeader.biWidth = @intCast(i32, width);
    bitmap_info.bmiHeader.biHeight = @intCast(i32, height);

    main_allocator.free(bitmap_memory);
    bitmap_memory = main_allocator.alloc(u32, width * height * 4) catch unreachable;

    main_allocator.free(depth_buffer);
    depth_buffer = main_allocator.alloc(f32, win_width * win_height) catch unreachable;

    screen_buffer = @ptrCast(*[]u8, &bitmap_memory).*;
}

fn win32UpadateWindow(device_context: win.HDC) void {
    _ = StretchDIBits(device_context, 0, 0, @intCast(c_int, win_width), @intCast(c_int, win_height), 0, @intCast(c_int, win_height), @intCast(c_int, win_width), -@intCast(c_int, win_height), @ptrCast(*c_void, bitmap_memory.ptr), @ptrCast(*c_void, &bitmap_info), 0, 0xcc0020);
}
// === Globals =======================================
var bitmap_memory: []u32 = undefined;
pub var screen_buffer: []u8 = undefined;
pub var depth_buffer: []f32 = undefined;
pub var main_allocator: *std.mem.Allocator = undefined;
pub var win_width: u32 = 800;
pub var win_height: u32 = 600;
// ===================================================

pub fn plataformInit(al: *std.mem.Allocator, w_width: u32, w_height: u32, start_fn: fn () void, update_fn: fn (f32) void) !void {
    main_allocator = al;
    const instance = @ptrCast(win.HINSTANCE, win.kernel32.GetModuleHandleW(null).?);

    var window_class = WNDCLASSEXA{
        .style = usr32.CS_OWNDC | usr32.CS_HREDRAW | usr32.CS_VREDRAW,
        .lpfnWndProc = mainWindowCallback,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "PixelDrawWindowClass",
        .hIconSm = null,
    };

    if (usr32.RegisterClassExA(&window_class) == 0) {
        std.debug.panic("Win error {}\n", .{win.kernel32.GetLastError()});
    }

    var window_handle_maybe_null = usr32.CreateWindowExA(0, window_class.lpszClassName, "PixelDraw", WS_OVERLAPEDWINDOW | WS_VISIBLE, 0, 0, @intCast(i32, w_width), @intCast(i32, w_height), null, null, instance, null);

    win_width = w_width;
    win_height = w_height;

    if (window_handle_maybe_null) |window_handle| {
        _ = usr32.ShowWindow(window_handle, 1);

        win32ResizeDibSection(w_width, w_height);
        //depth_buffer = try main_allocator.alloc(f32, win_width * win_height);

        start_fn();

        var delta: f32 = 0.0;
        var initTime: i128 = 0;

        var msg: usr32.MSG = undefined;
        var running = true;
        while (running) {
            initTime = std.time.nanoTimestamp() - initTime;
            delta = @floatCast(f32, @intToFloat(f64, initTime) / 1000000000);
            initTime = std.time.nanoTimestamp();

            for (depth_buffer) |*it| it.* = std.math.inf_f32;

            for (keys_up) |*it| it.* = false;
            for (keys_down) |*it| it.* = false;
            while (usr32.PeekMessageA(&msg, null, 0, 0, 0x0001)) { // 0x0001 = PM_REMOVE
                if (msg.message == usr32.WM_QUIT) {
                    running = false;
                }
                _ = usr32.TranslateMessage(&msg);
                _ = usr32.DispatchMessageA(&msg);
            }

            const device_context = usr32.GetDC(window_handle).?;
            win32UpadateWindow(device_context);
            update_fn(delta);
        }
    } else {
        std.debug.panic("Unable to create Window - error: {}\n", .{win.kernel32.GetLastError()});
    }

    main_allocator.free(bitmap_memory);
}
