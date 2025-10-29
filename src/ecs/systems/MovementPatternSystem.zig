const std = @import("std");
const WorldMod = @import("../World.zig");
const MovementPatternComp = @import("../components/MovementPattern.zig");
const Transform2D = @import("../components/Transform2D.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");

pub const MovementPatternSystem = struct {
    player_entity: WorldMod.Entity,

    pub fn init(player_entity: WorldMod.Entity) MovementPatternSystem {
        return .{ .player_entity = player_entity };
    }

    /// Update all entities with movement patterns
    pub fn update(self: *MovementPatternSystem, world: *WorldMod.World, dt: f32) void {
        // Get player position for tracking patterns
        const player_pos = world.transform_store.get(self.player_entity);

        var pattern_it = world.movement_pattern_store.iterator();
        while (pattern_it.next()) |entry| {
            const entity = entry.key_ptr.*;
            const pattern = entry.value_ptr;

            if (world.transform_store.getPtr(entity)) |transform| {
                switch (pattern.pattern_type) {
                    .tracking => self.updateTracking(pattern, transform, player_pos, dt),
                    .circular => self.updateCircular(pattern, transform, dt),
                    .patrol => self.updatePatrol(pattern, transform, dt),
                    .stationary => {}, // Don't move
                }

                // Update sprite direction based on movement
                self.updateSpriteDirection(world, entity, transform);
            }
        }
    }

    /// Tracking pattern: Chase the player
    fn updateTracking(self: *MovementPatternSystem, pattern: *MovementPatternComp.MovementPattern, transform: *Transform2D.Transform2D, player_pos: ?Transform2D.Transform2D, dt: f32) void {
        _ = self;

        if (player_pos) |target| {
            // Calculate direction to player
            const dx = target.x - transform.x;
            const dy = target.y - transform.y;
            const distance = @sqrt(dx * dx + dy * dy);

            if (distance > 1.0) {
                // Normalize and apply speed
                const norm_dx = dx / distance;
                const norm_dy = dy / distance;

                // Smooth interpolation (lerp towards player)
                const lerp_factor = @min(pattern.tracking_lerp_speed * dt, 1.0);
                const move_distance = pattern.speed * dt;

                transform.x += norm_dx * move_distance * lerp_factor;
                transform.y += norm_dy * move_distance * lerp_factor;

                // Store last movement for sprite direction
                transform.last_dx = norm_dx * move_distance;
                transform.last_dy = norm_dy * move_distance;
            }
        }
    }

    /// Circular pattern: Orbit around a point
    fn updateCircular(self: *MovementPatternSystem, pattern: *MovementPatternComp.MovementPattern, transform: *Transform2D.Transform2D, dt: f32) void {
        _ = self;

        // Update angle
        const angle_delta = pattern.orbit_speed * dt;
        if (pattern.orbit_clockwise) {
            pattern.orbit_angle += angle_delta;
        } else {
            pattern.orbit_angle -= angle_delta;
        }

        // Keep angle in range [0, 2π]
        const two_pi = 2.0 * std.math.pi;
        while (pattern.orbit_angle > two_pi) {
            pattern.orbit_angle -= two_pi;
        }
        while (pattern.orbit_angle < 0.0) {
            pattern.orbit_angle += two_pi;
        }

        // Calculate position on circle
        const old_x = transform.x;
        const old_y = transform.y;

        transform.x = pattern.orbit_center_x + pattern.orbit_radius * @cos(pattern.orbit_angle);
        transform.y = pattern.orbit_center_y + pattern.orbit_radius * @sin(pattern.orbit_angle);

        // Store movement delta for sprite direction
        transform.last_dx = transform.x - old_x;
        transform.last_dy = transform.y - old_y;
    }

    /// Patrol pattern: Move between waypoints
    fn updatePatrol(self: *MovementPatternSystem, pattern: *MovementPatternComp.MovementPattern, transform: *Transform2D.Transform2D, dt: f32) void {
        _ = self;

        if (pattern.waypoints) |waypoints| {
            if (waypoints.len == 0) return;

            // Check if pausing at waypoint
            if (pattern.patrol_pause_timer < pattern.patrol_pause_time) {
                pattern.patrol_pause_timer += dt;
                return;
            }

            // Get target waypoint
            const target = waypoints[pattern.current_waypoint_index];

            // Calculate direction to waypoint
            const dx = target.x - transform.x;
            const dy = target.y - transform.y;
            const distance = @sqrt(dx * dx + dy * dy);

            // Check if reached waypoint
            if (distance < 5.0) {
                pattern.advanceWaypoint();
                return;
            }

            // Move towards waypoint
            const norm_dx = dx / distance;
            const norm_dy = dy / distance;
            const move_distance = pattern.speed * dt;

            transform.x += norm_dx * move_distance;
            transform.y += norm_dy * move_distance;

            // Store movement for sprite direction
            transform.last_dx = norm_dx * move_distance;
            transform.last_dy = norm_dy * move_distance;
        }
    }

    /// Update sprite direction based on movement
    fn updateSpriteDirection(self: *MovementPatternSystem, world: *WorldMod.World, entity: WorldMod.Entity, transform: *const Transform2D.Transform2D) void {
        _ = self;

        if (world.sprite_store.getPtr(entity)) |sprite| {
            // Determine direction based on last movement
            const abs_dx = @abs(transform.last_dx);
            const abs_dy = @abs(transform.last_dy);

            if (abs_dx > 0.1 or abs_dy > 0.1) {
                sprite.current = .walk;

                if (abs_dx > abs_dy) {
                    // Horizontal movement dominates
                    sprite.direction = if (transform.last_dx > 0) .right else .left;
                } else {
                    // Vertical movement dominates
                    sprite.direction = if (transform.last_dy > 0) .front else .back;
                }
            } else {
                sprite.current = .idle;
            }
        }
    }
};
