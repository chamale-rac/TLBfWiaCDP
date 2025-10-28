const raylib = @import("raylib");

// EnemySpawner component - controls spawning of enemies
pub const EnemySpawner = struct {
    // Spawner configuration
    pattern: SpawnPattern = .random,
    enemy_type: []const u8 = "mouse",

    // Spawning parameters
    spawn_interval: f32 = 3.0, // seconds between spawns
    max_enemies: u32 = 10, // maximum enemies this spawner can have active
    enemies_per_spawn: u32 = 1, // how many enemies to spawn at once

    // Spawn area/position
    center_x: f32 = 0.0,
    center_y: f32 = 0.0,
    radius: f32 = 200.0, // radius for circular/random patterns
    width: f32 = 400.0, // width for line/rectangle patterns
    height: f32 = 400.0, // height for line/rectangle patterns

    // Runtime state
    time_until_next_spawn: f32 = 0.0,
    total_spawned: u32 = 0,
    active_enemies: u32 = 0,
    enabled: bool = true,

    pub const SpawnPattern = enum {
        line_horizontal,
        line_vertical,
        circular,
        random,
    };

    pub fn resetTimer(self: *EnemySpawner) void {
        self.time_until_next_spawn = self.spawn_interval;
    }

    pub fn getSpawnColor(self: *const EnemySpawner) raylib.Color {
        return switch (self.pattern) {
            .line_horizontal => raylib.Color{ .r = 255, .g = 165, .b = 0, .a = 150 }, // Orange
            .line_vertical => raylib.Color{ .r = 255, .g = 255, .b = 0, .a = 150 }, // Yellow
            .circular => raylib.Color{ .r = 0, .g = 191, .b = 255, .a = 150 }, // Deep sky blue
            .random => raylib.Color{ .r = 255, .g = 0, .b = 255, .a = 150 }, // Magenta
        };
    }
};
