/// Point structure for collision detection
pub const CollisionPoint = struct {
    x: f32,
    y: f32,
};

/// Shared collision configuration for consistent collision detection across systems
pub const CollisionConfig = struct {
    // Sprite dimensions
    pub const SPRITE_WIDTH: f32 = 64.0;
    pub const SPRITE_HEIGHT: f32 = 64.0;
    pub const SPRITE_HALF_WIDTH: f32 = 32.0;
    pub const SPRITE_HALF_HEIGHT: f32 = 32.0;

    // Collision bounds insets (adjust to desired tightness)
    pub const NORTH_INSET: f32 = 16.0; // inset north (top)
    pub const SOUTH_INSET: f32 = 4.0; // inset south (bottom)
    pub const WEST_INSET: f32 = 22.0; // inset west (left)
    pub const EAST_INSET: f32 = 22.0; // inset east (right)
};

/// Calculate collision points for a given position
/// Returns an array of collision points to test for walkability
pub fn getCollisionPoints(x: f32, y: f32) [8]CollisionPoint {
    const center_x = x + CollisionConfig.SPRITE_HALF_WIDTH;
    const center_y = y + CollisionConfig.SPRITE_HALF_HEIGHT;

    return [_]CollisionPoint{
        // Corners (inset)
        .{ .x = x + CollisionConfig.WEST_INSET, .y = y + CollisionConfig.NORTH_INSET }, // top-left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = y + CollisionConfig.NORTH_INSET }, // top-right
        .{ .x = x + CollisionConfig.WEST_INSET, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom-left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom-right
        // Midpoints of edges (inset)
        .{ .x = center_x, .y = y + CollisionConfig.NORTH_INSET }, // top
        .{ .x = center_x, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom
        .{ .x = x + CollisionConfig.WEST_INSET, .y = center_y }, // left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = center_y }, // right
    };
}

/// Calculate collision points for debug rendering (includes center point)
/// Returns an array of collision points for visual debugging
pub fn getDebugCollisionPoints(x: f32, y: f32) [9]CollisionPoint {
    const center_x = x + CollisionConfig.SPRITE_HALF_WIDTH;
    const center_y = y + CollisionConfig.SPRITE_HALF_HEIGHT;

    return [_]CollisionPoint{
        // Center of sprite
        .{ .x = center_x, .y = center_y },
        // Corners (inset)
        .{ .x = x + CollisionConfig.WEST_INSET, .y = y + CollisionConfig.NORTH_INSET }, // top-left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = y + CollisionConfig.NORTH_INSET }, // top-right
        .{ .x = x + CollisionConfig.WEST_INSET, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom-left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom-right
        // Midpoints of edges (inset)
        .{ .x = center_x, .y = y + CollisionConfig.NORTH_INSET }, // top
        .{ .x = center_x, .y = y + CollisionConfig.SPRITE_HEIGHT - CollisionConfig.SOUTH_INSET }, // bottom
        .{ .x = x + CollisionConfig.WEST_INSET, .y = center_y }, // left
        .{ .x = x + CollisionConfig.SPRITE_WIDTH - CollisionConfig.EAST_INSET, .y = center_y }, // right
    };
}
