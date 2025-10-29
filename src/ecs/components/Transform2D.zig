pub const Transform2D = struct {
    x: f32,
    y: f32,
    scale_x: f32 = 1,
    scale_y: f32 = 1,
    rotation_deg: f32 = 0,
    // Store last movement for sprite direction updates
    last_dx: f32 = 0.0,
    last_dy: f32 = 0.0,
};
