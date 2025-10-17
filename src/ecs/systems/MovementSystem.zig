const WorldMod = @import("../World.zig");
const IntGridSystem = @import("IntGridSystem.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const MovementSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (world.transform_store.getPtr(e)) |tr| {
                const v = entry.value_ptr.*;

                // Calculate new position
                const new_x = tr.x + v.vx * dt;
                const new_y = tr.y + v.vy * dt;

                // Check if the new position is walkable using bounding box collision
                if (isPositionWalkable(world, new_x, new_y)) {
                    tr.x = new_x;
                    tr.y = new_y;
                }
                // If not walkable, the entity stays in its current position
            }
        }
    }

    // Check if a position is walkable by testing multiple points around the sprite
    fn isPositionWalkable(world: *WorldMod.World, x: f32, y: f32) bool {
        // Get collision points from shared configuration
        const collision_points = CollisionConfig.getCollisionPoints(x, y);

        // All collision points must be walkable for the position to be valid
        for (collision_points) |point| {
            if (!IntGridSystem.IntGridSystem.isWalkableAt(world, point.x, point.y)) {
                return false;
            }
        }

        return true;
    }
};
