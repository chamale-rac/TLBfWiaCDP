//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const raylib = @import("raylib");
const raygui = @import("raygui");

pub fn main() !void {
    // Initialize raylib
    raylib.cdef.InitWindow(800, 450, "Raylib-Zig Example");
    defer raylib.cdef.CloseWindow();

    // Set target FPS
    raylib.cdef.SetTargetFPS(60);

    // Main game loop
    while (!raylib.cdef.WindowShouldClose()) {
        // Update
        // (Your game logic goes here)

        // Draw
        raylib.cdef.BeginDrawing();
        defer raylib.cdef.EndDrawing();

        raylib.cdef.ClearBackground(raylib.Color.ray_white);

        // Draw some text
        raylib.cdef.DrawText("Hello, Raylib-Zig!", 190, 200, 20, raylib.Color.dark_gray);
        raylib.cdef.DrawText("Press ESC to close", 190, 230, 20, raylib.Color.dark_gray);

        // Draw a simple shape
        raylib.cdef.DrawCircle(400, 300, 50, raylib.Color.blue);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("TLBfWiaCDP_lib");
