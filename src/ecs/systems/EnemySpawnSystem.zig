const std = @import("std");
const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const EnemySpawnerComp = @import("../components/EnemySpawner.zig");
const EnemyComp = @import("../components/Enemy.zig");
const LPC = @import("../../assets/LPC.zig");
const Assets = @import("../../assets/Assets.zig");
const Transform2D = @import("../components/Transform2D.zig");
const Velocity2D = @import("../components/Velocity2D.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");
const ZIndex = @import("../components/ZIndex.zig");
const MovementPatternComp = @import("../components/MovementPattern.zig");

pub const EnemySpawnSystem = struct {
    // RNG for random spawning
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) EnemySpawnSystem {
        return .{
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Update all spawners, spawning enemies when needed
    pub fn update(self: *EnemySpawnSystem, world: *WorldMod.World, assets: *Assets.Assets, dt: f32) !void {
        // Get game time from the game timer
        var game_time: f32 = 0.0;
        var timer_it = world.game_timer_store.iterator();
        if (timer_it.next()) |entry| {
            game_time = entry.value_ptr.elapsed_time;
        }

        var spawner_it = world.spawner_store.iterator();
        while (spawner_it.next()) |entry| {
            const spawner_entity = entry.key_ptr.*;
            const spawner = entry.value_ptr;

            if (!spawner.enabled) continue;

            // Check if spawner is active based on game time
            spawner.is_active_by_time = spawner.isActiveAtTime(game_time);

            if (!spawner.is_active_by_time) continue;

            // Update timer
            spawner.time_until_next_spawn -= dt;

            // Check if it's time to spawn
            if (spawner.time_until_next_spawn <= 0.0) {
                // Check if we can spawn more enemies
                if (spawner.active_enemies < spawner.max_enemies) {
                    try self.spawnEnemies(world, assets, spawner_entity, spawner);
                }
                spawner.resetTimer();
            }
        }
    }

    /// Spawn enemies based on the spawner's pattern
    fn spawnEnemies(self: *EnemySpawnSystem, world: *WorldMod.World, assets: *Assets.Assets, spawner_entity: WorldMod.Entity, spawner: *EnemySpawnerComp.EnemySpawner) !void {
        const count = spawner.enemies_per_spawn;
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const pos = self.calculateSpawnPosition(spawner, i, count);
            try self.createEnemy(world, assets, spawner_entity, pos.x, pos.y);
            spawner.total_spawned += 1;
            spawner.active_enemies += 1;
        }
    }

    /// Calculate spawn position based on pattern
    fn calculateSpawnPosition(self: *EnemySpawnSystem, spawner: *EnemySpawnerComp.EnemySpawner, index: u32, total: u32) struct { x: f32, y: f32 } {
        const random = self.rng.random();

        return switch (spawner.pattern) {
            .line_horizontal => blk: {
                const spacing = spawner.width / @as(f32, @floatFromInt(total));
                const x = spawner.center_x - spawner.width / 2.0 + spacing * @as(f32, @floatFromInt(index)) + spacing / 2.0;
                const y = spawner.center_y;
                break :blk .{ .x = x, .y = y };
            },
            .line_vertical => blk: {
                const spacing = spawner.height / @as(f32, @floatFromInt(total));
                const x = spawner.center_x;
                const y = spawner.center_y - spawner.height / 2.0 + spacing * @as(f32, @floatFromInt(index)) + spacing / 2.0;
                break :blk .{ .x = x, .y = y };
            },
            .circular => blk: {
                const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(total));
                const x = spawner.center_x + spawner.radius * @cos(angle);
                const y = spawner.center_y + spawner.radius * @sin(angle);
                break :blk .{ .x = x, .y = y };
            },
            .random => blk: {
                // Random position within a rectangle
                const x = spawner.center_x - spawner.width / 2.0 + random.float(f32) * spawner.width;
                const y = spawner.center_y - spawner.height / 2.0 + random.float(f32) * spawner.height;
                break :blk .{ .x = x, .y = y };
            },
        };
    }

    /// Create an enemy entity
    fn createEnemy(self: *EnemySpawnSystem, world: *WorldMod.World, assets: *Assets.Assets, spawner_entity: WorldMod.Entity, x: f32, y: f32) !void {
        const enemy = world.create();

        // Get spawner to determine enemy type
        const spawner = world.spawner_store.get(spawner_entity) orelse return;
        const enemy_type = spawner.enemy_type;

        // Transform
        try world.transform_store.set(enemy, .{ .x = x, .y = y });

        // NOTE: Enemies don't use Velocity - they use MovementPattern instead
        // This prevents them from being affected by special tiles and player movement logic

        // Select texture based on enemy type
        const texture = switch (enemy_type) {
            .mouse => assets.enemy_mouse,
            .rabbit => assets.enemy_rabbit,
            .sheep => assets.enemy_sheep,
            .wolf => assets.enemy_wolf,
            .lizard => assets.enemy_lizard,
        };

        // Animated sprite (all use same LPC format)
        try world.sprite_store.set(enemy, .{
            .texture = texture,
            .grid = LPC.mouseGrid(), // Same grid for all LPC sprites
            .set = LPC.mouseAnimationSet(), // Same animation set for all
            .current = .idle,
            .direction = .front,
            .seconds_per_frame = 0.12,
            .layer = 0,
        });

        // Z-index
        try world.z_index_store.set(enemy, .{ .value = 0 });

        // Enemy component with random initial wander direction
        const random = self.rng.random();
        const initial_state_time = 1.0 + random.float(f32) * 2.0;

        // Convert spawner enemy type to component enemy type
        const component_enemy_type: EnemyComp.Enemy.EnemyType = switch (enemy_type) {
            .mouse => .mouse,
            .rabbit => .rabbit,
            .sheep => .sheep,
            .wolf => .wolf,
            .lizard => .lizard,
        };

        try world.enemy_store.set(enemy, .{
            .enemy_type = component_enemy_type,
            .ai_state = .idle,
            .speed = 40.0 + random.float(f32) * 20.0, // Random speed between 40-60
            .state_timer = 0.0,
            .next_state_change = initial_state_time,
        });

        // Create movement pattern based on spawner configuration
        try self.createMovementPattern(world, enemy, spawner, x, y);
    }

    /// Create and assign movement pattern to enemy
    fn createMovementPattern(self: *EnemySpawnSystem, world: *WorldMod.World, enemy: WorldMod.Entity, spawner: EnemySpawnerComp.EnemySpawner, spawn_x: f32, spawn_y: f32) !void {
        const random = self.rng.random();

        // Calculate random speed between min and max
        const speed_range = spawner.movement_speed_max - spawner.movement_speed_min;
        const random_speed = spawner.movement_speed_min + (random.float(f32) * speed_range);

        var movement_pattern = MovementPatternComp.MovementPattern{
            .speed = random_speed,
        };

        switch (spawner.movement_pattern) {
            .tracking => {
                movement_pattern.pattern_type = .tracking;
                movement_pattern.tracking_lerp_speed = spawner.tracking_lerp;
            },
            .circular => {
                movement_pattern.pattern_type = .circular;
                movement_pattern.orbit_center_x = spawn_x;
                movement_pattern.orbit_center_y = spawn_y;
                movement_pattern.orbit_radius = spawner.orbit_radius;
                movement_pattern.orbit_speed = spawner.orbit_speed;
                movement_pattern.orbit_clockwise = spawner.orbit_clockwise;
                movement_pattern.orbit_angle = random.float(f32) * 2.0 * std.math.pi; // Random starting angle
            },
            .patrol => {
                movement_pattern.pattern_type = .patrol;
                movement_pattern.patrol_pause_time = spawner.patrol_pause;
                movement_pattern.patrol_loop = spawner.patrol_loop;

                // Create simple patrol waypoints around spawn point
                // (In a real scenario, these would come from JSON)
                const patrol_size: f32 = 100.0;
                const waypoints = try world.allocator.alloc(MovementPatternComp.MovementPattern.Waypoint, 4);
                waypoints[0] = .{ .x = spawn_x - patrol_size, .y = spawn_y - patrol_size };
                waypoints[1] = .{ .x = spawn_x + patrol_size, .y = spawn_y - patrol_size };
                waypoints[2] = .{ .x = spawn_x + patrol_size, .y = spawn_y + patrol_size };
                waypoints[3] = .{ .x = spawn_x - patrol_size, .y = spawn_y + patrol_size };
                movement_pattern.waypoints = waypoints;
            },
            .stationary => {
                movement_pattern.pattern_type = .stationary;
            },
        }

        try world.movement_pattern_store.set(enemy, movement_pattern);
    }

    /// Clean up dead enemies and update spawner counts
    pub fn cleanupDeadEnemies(world: *WorldMod.World) void {
        // In a real game, you'd check for dead enemies and remove them
        // For now, this is a placeholder for future death/cleanup logic
        _ = world;
    }
};
