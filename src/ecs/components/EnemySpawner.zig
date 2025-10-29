const raylib = @import("raylib");

pub const EnemyType = enum {
    mouse,
    rabbit,
    sheep,
    wolf,
    lizard,
};

// EnemySpawner component - controls spawning of enemies
pub const EnemySpawner = struct {
    // Spawner configuration
    pattern: SpawnPattern = .random,
    enemy_type: EnemyType = .mouse,

    // Time-based activation (survival time in seconds)
    start_time: f32 = 0.0, // When this spawner becomes active (survival time)
    end_time: f32 = -1.0, // When this spawner stops (-1 = never stops)

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
    is_active_by_time: bool = false, // Whether the spawner is active based on game time

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
        const base_color = switch (self.pattern) {
            .line_horizontal => raylib.Color{ .r = 255, .g = 165, .b = 0, .a = 150 }, // Orange
            .line_vertical => raylib.Color{ .r = 255, .g = 255, .b = 0, .a = 150 }, // Yellow
            .circular => raylib.Color{ .r = 0, .g = 191, .b = 255, .a = 150 }, // Deep sky blue
            .random => raylib.Color{ .r = 255, .g = 0, .b = 255, .a = 150 }, // Magenta
        };

        // Dim the color if not active yet
        if (!self.is_active_by_time) {
            return raylib.Color{ .r = base_color.r / 3, .g = base_color.g / 3, .b = base_color.b / 3, .a = 100 };
        }

        return base_color;
    }

    pub fn isActiveAtTime(self: *const EnemySpawner, game_time: f32) bool {
        if (game_time < self.start_time) return false;
        if (self.end_time >= 0.0 and game_time > self.end_time) return false;
        return true;
    }
};
