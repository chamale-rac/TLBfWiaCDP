const AnimatedSprite = @import("../ecs/components/AnimatedSprite.zig");

pub fn lpcGrid() AnimatedSprite.FrameGrid {
    return .{ .image_width = 832, .image_height = 3456, .frame_width = 64, .frame_height = 64 };
}

pub fn lpcAnimationSet() AnimatedSprite.AnimationSet {
    return .{
        .idle = .{ .start_row = 22, .frames = &[_]i32{ 1, 1, 0 } },
        .walk = .{ .start_row = 4, .frames = &[_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 } },
        .run = .{ .start_row = 38, .frames = &[_]i32{ 1, 2, 3, 4, 5, 6, 7 } },
    };
}
