A lib to draw struff on the screen easily writen in zig

```zig
const draw = @import("pixel_draw.zig");

var main_allocator: *Allocator = undefined;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    main_allocator = &gpa.allocator;
    
    try draw.init(&gpa.allocator, 1280, 720, start, update);
}

fn start() void {

}


fn update(delta: f32) void {
    draw.gb.fillScreenWithRGBColor(100, 100, 100);
    
    // Draw a white line
    draw.gb.drawLine(100, 100, 200, 200, draw.Color.c(1.0, 1.0, 1.0, 1.0));
    
    // Draw a blue circle with a radius of 50 pixels
    draw.gb.fillCircle(200, 200, 50, draw.Color.c(0.0, 0.0, 1.0, 1.0))
}
```
