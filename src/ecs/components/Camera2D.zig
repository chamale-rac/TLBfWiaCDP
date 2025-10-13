const std = @import("std");

pub const Camera2D = struct {
    // Follow target entity id (if any)
    target_entity: ?u32 = null,

    // Camera parameters
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    zoom: f32 = 2,
    rotation_deg: f32 = 0,

    // Computed target position in world space (center of camera)
    computed_target_x: f32 = 0,
    computed_target_y: f32 = 0,

    // Follow smoothing: units per second factor (0 = snap)
    follow_lerp_speed: f32 = 0,

    // Simple screen shake effect
    shake_time_remaining: f32 = 0,
    shake_intensity: f32 = 0, // in world units
    shake_frequency: f32 = 25.0,
};
