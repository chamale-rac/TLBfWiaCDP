const std = @import("std");
const WorldMod = @import("../World.zig");
const EnemyComp = @import("../components/Enemy.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");

pub const EnemyAISystem = struct {
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) EnemyAISystem {
        return .{
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Update AI for all enemies
    pub fn update(self: *EnemyAISystem, world: *WorldMod.World, dt: f32) void {
        var enemy_it = world.enemy_store.iterator();
        while (enemy_it.next()) |entry| {
            const entity = entry.key_ptr.*;
            const enemy = entry.value_ptr;

            // Update state timer
            enemy.state_timer += dt;

            // Check if it's time to change state
            if (enemy.state_timer >= enemy.next_state_change) {
                enemy.state_timer = 0.0;
                self.transitionState(enemy);
            }

            // Execute current state behavior
            switch (enemy.ai_state) {
                .idle => self.executeIdle(world, entity, enemy),
                .wander => self.executeWander(world, entity, enemy),
            }
        }
    }

    fn transitionState(self: *EnemyAISystem, enemy: *EnemyComp.Enemy) void {
        const random = self.rng.random();

        // Randomly choose next state
        const next_state = if (random.float(f32) < 0.5)
            EnemyComp.Enemy.AIState.idle
        else
            EnemyComp.Enemy.AIState.wander;

        enemy.ai_state = next_state;
        enemy.next_state_change = 1.0 + random.float(f32) * 3.0; // 1-4 seconds
    }

    fn executeIdle(self: *EnemyAISystem, world: *WorldMod.World, entity: WorldMod.Entity, enemy: *EnemyComp.Enemy) void {
        _ = self;
        _ = enemy;

        // Stop movement
        if (world.velocity_store.getPtr(entity)) |vel| {
            vel.vx = 0;
            vel.vy = 0;
        }

        // Set animation to idle
        if (world.sprite_store.getPtr(entity)) |sprite| {
            sprite.current = .idle;
        }
    }

    fn executeWander(self: *EnemyAISystem, world: *WorldMod.World, entity: WorldMod.Entity, enemy: *EnemyComp.Enemy) void {
        const random = self.rng.random();

        if (world.velocity_store.getPtr(entity)) |vel| {
            // Random direction
            const angle = random.float(f32) * 2.0 * std.math.pi;
            vel.vx = @cos(angle) * enemy.speed;
            vel.vy = @sin(angle) * enemy.speed;
        }

        // Set animation to walk
        if (world.sprite_store.getPtr(entity)) |sprite| {
            sprite.current = .walk;
        }
    }
};
