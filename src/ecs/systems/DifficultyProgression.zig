const std = @import("std");
const EnemySpawnerComp = @import("../components/EnemySpawner.zig");

pub const EnemyProfile = struct {
    enemy_type: EnemySpawnerComp.EnemyType,
    movement_pattern: EnemySpawnerComp.MovementPatternType = .stationary,
    movement_speed_min: f32 = 40.0,
    movement_speed_max: f32 = 60.0,
    tracking_lerp: f32 = 2.0,
    orbit_radius: f32 = 120.0,
    orbit_speed: f32 = 1.0,
    orbit_clockwise: bool = true,
    patrol_pause: f32 = 0.0,
    patrol_loop: bool = true,
    spawn_interval: f32,
    spawn_interval_jitter: f32 = 0.0,
    enemies_per_spawn: u32,
    max_enemies: u32,
    weight: f32 = 1.0,
};

pub const DifficultyStage = struct {
    name: []const u8,
    start_time: f32,
    end_time: f32 = -1.0,
    profiles: []const EnemyProfile,

    pub fn chooseProfile(self: DifficultyStage, random: std.Random) EnemyProfile {
        if (self.profiles.len == 0) return EnemyProfile{
            .enemy_type = .mouse,
            .spawn_interval = 10.0,
            .enemies_per_spawn = 1,
            .max_enemies = 4,
        };

        var total_weight: f32 = 0.0;
        for (self.profiles) |profile| {
            total_weight += if (profile.weight > 0.0) profile.weight else 0.0;
        }

        if (total_weight <= 0.0) return self.profiles[0];

        const pick = random.float(f32) * total_weight;
        var accumulator: f32 = 0.0;
        for (self.profiles) |profile| {
            const weight = if (profile.weight > 0.0) profile.weight else 0.0;
            accumulator += weight;
            if (pick <= accumulator) {
                return profile;
            }
        }

        return self.profiles[self.profiles.len - 1];
    }
};

pub const DifficultyProgression = struct {
    stages: []const DifficultyStage,

    pub fn stageIndexForTime(self: DifficultyProgression, time: f32) ?usize {
        var i: usize = 0;
        while (i < self.stages.len) : (i += 1) {
            const stage = self.stages[i];
            const end_ok = stage.end_time < 0.0 or time < stage.end_time;
            if (time >= stage.start_time and end_ok) {
                return i;
            }
        }
        return null;
    }

    pub fn getStage(self: DifficultyProgression, time: f32) ?DifficultyStage {
        if (self.stageIndexForTime(time)) |idx| {
            return self.stages[idx];
        }
        return null;
    }
};

// Default difficulty curve used by the game. The stages increase enemy pressure over time.
const calm_profiles = [_]EnemyProfile{
    .{
        .enemy_type = .mouse,
        .movement_pattern = .stationary,
        .movement_speed_min = 30.0,
        .movement_speed_max = 45.0,
        .spawn_interval = 8.0,
        .spawn_interval_jitter = 0.15,
        .enemies_per_spawn = 1,
        .max_enemies = 4,
        .weight = 0.6,
    },
    .{
        .enemy_type = .rabbit,
        .movement_pattern = .patrol,
        .movement_speed_min = 45.0,
        .movement_speed_max = 60.0,
        .patrol_pause = 0.4,
        .spawn_interval = 9.0,
        .spawn_interval_jitter = 0.2,
        .enemies_per_spawn = 2,
        .max_enemies = 6,
        .weight = 0.4,
    },
};

const growing_profiles = [_]EnemyProfile{
    .{
        .enemy_type = .rabbit,
        .movement_pattern = .tracking,
        .movement_speed_min = 55.0,
        .movement_speed_max = 75.0,
        .tracking_lerp = 2.5,
        .spawn_interval = 7.0,
        .spawn_interval_jitter = 0.2,
        .enemies_per_spawn = 2,
        .max_enemies = 7,
        .weight = 0.5,
    },
    .{
        .enemy_type = .sheep,
        .movement_pattern = .circular,
        .movement_speed_min = 45.0,
        .movement_speed_max = 65.0,
        .orbit_radius = 140.0,
        .orbit_speed = 1.4,
        .spawn_interval = 6.5,
        .spawn_interval_jitter = 0.15,
        .enemies_per_spawn = 3,
        .max_enemies = 8,
        .weight = 0.5,
    },
};

const pressure_profiles = [_]EnemyProfile{
    .{
        .enemy_type = .sheep,
        .movement_pattern = .tracking,
        .movement_speed_min = 60.0,
        .movement_speed_max = 85.0,
        .tracking_lerp = 3.0,
        .spawn_interval = 5.5,
        .spawn_interval_jitter = 0.15,
        .enemies_per_spawn = 3,
        .max_enemies = 9,
        .weight = 0.4,
    },
    .{
        .enemy_type = .wolf,
        .movement_pattern = .circular,
        .movement_speed_min = 70.0,
        .movement_speed_max = 95.0,
        .orbit_radius = 160.0,
        .orbit_speed = 1.8,
        .spawn_interval = 4.5,
        .spawn_interval_jitter = 0.2,
        .enemies_per_spawn = 4,
        .max_enemies = 10,
        .weight = 0.6,
    },
};

const survival_profiles = [_]EnemyProfile{
    .{
        .enemy_type = .wolf,
        .movement_pattern = .tracking,
        .movement_speed_min = 95.0,
        .movement_speed_max = 130.0,
        .tracking_lerp = 3.5,
        .spawn_interval = 3.5,
        .spawn_interval_jitter = 0.2,
        .enemies_per_spawn = 4,
        .max_enemies = 12,
        .weight = 0.5,
    },
    .{
        .enemy_type = .lizard,
        .movement_pattern = .circular,
        .movement_speed_min = 80.0,
        .movement_speed_max = 120.0,
        .orbit_radius = 200.0,
        .orbit_speed = 2.2,
        .orbit_clockwise = false,
        .spawn_interval = 3.0,
        .spawn_interval_jitter = 0.25,
        .enemies_per_spawn = 5,
        .max_enemies = 14,
        .weight = 0.5,
    },
};

pub const default_progression = DifficultyProgression{
    .stages = &[_]DifficultyStage{
        .{
            .name = "Calm Skirmishes",
            .start_time = 0.0,
            .end_time = 30.0,
            .profiles = &calm_profiles,
        },
        .{
            .name = "Growing Threat",
            .start_time = 30.0,
            .end_time = 60.0,
            .profiles = &growing_profiles,
        },
        .{
            .name = "Sustained Pressure",
            .start_time = 60.0,
            .end_time = 90.0,
            .profiles = &pressure_profiles,
        },
        .{
            .name = "Survival Mode",
            .start_time = 90.0,
            .end_time = -1.0,
            .profiles = &survival_profiles,
        },
    },
};
