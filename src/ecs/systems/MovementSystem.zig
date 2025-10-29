const WorldMod = @import("../World.zig");
const IntGridSystem = @import("IntGridSystem.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");
const SpecialTilesMod = @import("../components/SpecialTiles.zig");

pub const MovementSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;

            // Skip entities with movement patterns (enemies)
            if (world.movement_pattern_store.contains(e)) {
                continue;
            }

            if (world.transform_store.getPtr(e)) |tr| {
                const v = entry.value_ptr.*;

                // Get speed modifier from special tiles
                const speed_modifier = getSpeedModifierAtPosition(world, tr.x, tr.y);

                // Apply special tile effects (like push/teleport)
                const should_push = checkForPushTeleport(world, tr.x, tr.y);
                if (should_push and (v.vx != 0 or v.vy != 0)) {
                    // Teleport player forward based on movement direction
                    applyPushTeleport(world, tr, v.vx, v.vy);
                    // Snap camera to entity that was teleported
                    snapCameraToEntity(world, e);
                    continue; // Skip normal movement after teleport
                }

                // Calculate new position with speed modifier applied
                const new_x = tr.x + v.vx * dt * speed_modifier;
                const new_y = tr.y + v.vy * dt * speed_modifier;

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

    // Get speed modifier based on special tile at position
    fn getSpeedModifierAtPosition(world: *WorldMod.World, x: f32, y: f32) f32 {
        // Use center of sprite for tile detection
        const center_x = x + CollisionConfig.CollisionConfig.SPRITE_HALF_WIDTH;
        const center_y = y + CollisionConfig.CollisionConfig.SPRITE_HALF_HEIGHT;

        // Get tile coordinates
        const tile_coords = IntGridSystem.IntGridSystem.getTileCoordinates(world, center_x, center_y) orelse return 1.0;

        // Check special tiles store
        var special_tiles_it = world.special_tiles_store.iterator();
        while (special_tiles_it.next()) |entry| {
            const special_tiles = entry.value_ptr;
            const tile_type = special_tiles.get(tile_coords.tile_x, tile_coords.tile_y);

            return switch (tile_type) {
                .slowdown => 0.5, // 50% speed
                .speedup => 2.0, // 200% speed
                .push_teleport => 1.0, // Normal speed (teleport handled separately)
                .none => 1.0, // Normal speed
            };
        }

        return 1.0; // Default to normal speed
    }

    // Check if player is on a push/teleport tile
    fn checkForPushTeleport(world: *WorldMod.World, x: f32, y: f32) bool {
        // Use center of sprite for tile detection
        const center_x = x + CollisionConfig.CollisionConfig.SPRITE_HALF_WIDTH;
        const center_y = y + CollisionConfig.CollisionConfig.SPRITE_HALF_HEIGHT;

        // Get tile coordinates
        const tile_coords = IntGridSystem.IntGridSystem.getTileCoordinates(world, center_x, center_y) orelse return false;

        // Check special tiles store
        var special_tiles_it = world.special_tiles_store.iterator();
        while (special_tiles_it.next()) |entry| {
            const special_tiles = entry.value_ptr;
            const tile_type = special_tiles.get(tile_coords.tile_x, tile_coords.tile_y);

            if (tile_type == .push_teleport) {
                return true;
            }
        }

        return false;
    }

    // Apply push/teleport effect
    fn applyPushTeleport(world: *WorldMod.World, transform: *@import("../components/Transform2D.zig").Transform2D, vx: f32, vy: f32) void {
        // Get tile size for calculating teleport distance
        const tile_coords = IntGridSystem.IntGridSystem.getTileCoordinates(
            world,
            transform.x + CollisionConfig.CollisionConfig.SPRITE_HALF_WIDTH,
            transform.y + CollisionConfig.CollisionConfig.SPRITE_HALF_HEIGHT,
        ) orelse return;

        const tile_size = tile_coords.tile_size;

        // Normalize direction
        const magnitude = @sqrt(vx * vx + vy * vy);
        if (magnitude == 0) return;

        const dir_x = vx / magnitude;
        const dir_y = vy / magnitude;

        // Teleport 4 tiles forward in the movement direction
        const teleport_distance = tile_size * 4.0;
        const new_x = transform.x + dir_x * teleport_distance;
        const new_y = transform.y + dir_y * teleport_distance;

        // Only teleport if the new position is walkable
        if (isPositionWalkable(world, new_x, new_y)) {
            transform.x = new_x;
            transform.y = new_y;
        }
    }

    /// Snap any camera following this entity to its current position
    fn snapCameraToEntity(world: *WorldMod.World, entity: WorldMod.Entity) void {
        var cam_it = world.camera_store.iterator();
        while (cam_it.next()) |entry| {
            var cam = entry.value_ptr;
            if (cam.target_entity) |target| {
                if (target == entity) {
                    // This camera is following the entity, snap it
                    if (world.transform_store.get(entity)) |tr| {
                        cam.computed_target_x = tr.x;
                        cam.computed_target_y = tr.y;
                    }
                }
            }
        }
    }
};
