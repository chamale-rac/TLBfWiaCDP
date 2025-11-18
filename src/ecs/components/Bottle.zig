const raylib = @import("raylib");

/// Collectible bottle placed on the ground.
pub const Bottle = struct {
    /// World-space center position in pixels (affected by camera transforms).
    x: f32,
    y: f32,
    /// Radius of the bottle pickup circle.
    radius: f32,
    /// Whether the player has already collected this bottle.
    collected: bool = false,
    /// Optional tint to differentiate bottles (defaults to aqua tone).
    tint: raylib.Color = raylib.Color{ .r = 0, .g = 200, .b = 255, .a = 255 },
};
