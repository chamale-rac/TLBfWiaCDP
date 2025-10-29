const std = @import("std");
const WorldMod = @import("../World.zig");
const EnemySpawnerComp = @import("../components/EnemySpawner.zig");

pub const SpawnerConfigLoader = struct {
    pub fn loadFromFile(world: *WorldMod.World, allocator: std.mem.Allocator, file_path: []const u8) !void {
        // Read file contents
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        _ = try file.readAll(buffer);

        // Parse JSON
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const spawners_array = root.get("spawners").?.array;

        // Create spawner entities
        for (spawners_array.items) |spawner_json| {
            const spawner_obj = spawner_json.object;

            const pattern_str = spawner_obj.get("pattern").?.string;
            const pattern = parsePattern(pattern_str);

            const enemy_type_str = spawner_obj.get("enemy_type").?.string;
            const enemy_type = parseEnemyType(enemy_type_str);

            // Parse movement pattern
            const movement_pattern_str = spawner_obj.get("movement_pattern") orelse null;
            const movement_pattern = if (movement_pattern_str) |mp| parseMovementPattern(mp.string) else .stationary;
            
            const movement_speed_min = if (spawner_obj.get("movement_speed_min")) |ms| @as(f32, @floatCast(ms.float)) else 40.0;
            const movement_speed_max = if (spawner_obj.get("movement_speed_max")) |ms| @as(f32, @floatCast(ms.float)) else 60.0;
            const tracking_lerp = if (spawner_obj.get("tracking_lerp")) |tl| @as(f32, @floatCast(tl.float)) else 2.0;
            const orbit_radius = if (spawner_obj.get("orbit_radius")) |or_val| @as(f32, @floatCast(or_val.float)) else 100.0;
            const orbit_speed = if (spawner_obj.get("orbit_speed")) |os| @as(f32, @floatCast(os.float)) else 1.0;
            const orbit_clockwise = if (spawner_obj.get("orbit_clockwise")) |oc| oc.bool else true;
            const patrol_pause = if (spawner_obj.get("patrol_pause")) |pp| @as(f32, @floatCast(pp.float)) else 0.0;
            const patrol_loop = if (spawner_obj.get("patrol_loop")) |pl| pl.bool else true;

            const spawner_entity = world.create();
            try world.spawner_store.set(spawner_entity, .{
                .pattern = pattern,
                .enemy_type = enemy_type,
                .movement_pattern = movement_pattern,
                .movement_speed_min = movement_speed_min,
                .movement_speed_max = movement_speed_max,
                .tracking_lerp = tracking_lerp,
                .orbit_radius = orbit_radius,
                .orbit_speed = orbit_speed,
                .orbit_clockwise = orbit_clockwise,
                .patrol_pause = patrol_pause,
                .patrol_loop = patrol_loop,
                .start_time = @floatCast(spawner_obj.get("start_time").?.float),
                .end_time = @floatCast(spawner_obj.get("end_time").?.float),
                .spawn_interval = @floatCast(spawner_obj.get("spawn_interval").?.float),
                .max_enemies = @intCast(spawner_obj.get("max_enemies").?.integer),
                .enemies_per_spawn = @intCast(spawner_obj.get("enemies_per_spawn").?.integer),
                .center_x = @floatCast(spawner_obj.get("center_x").?.float),
                .center_y = @floatCast(spawner_obj.get("center_y").?.float),
                .radius = @floatCast(spawner_obj.get("radius").?.float),
                .width = @floatCast(spawner_obj.get("width").?.float),
                .height = @floatCast(spawner_obj.get("height").?.float),
                .time_until_next_spawn = @floatCast(spawner_obj.get("spawn_interval").?.float),
                .enabled = spawner_obj.get("enabled").?.bool,
            });

            // Store patrol waypoints separately if provided
            if (spawner_obj.get("patrol_waypoints")) |waypoints_json| {
                // We'll handle this in the spawn system
                _ = waypoints_json;
            }
        }
    }

    fn parsePattern(pattern_str: []const u8) EnemySpawnerComp.EnemySpawner.SpawnPattern {
        if (std.mem.eql(u8, pattern_str, "line_horizontal")) {
            return .line_horizontal;
        } else if (std.mem.eql(u8, pattern_str, "line_vertical")) {
            return .line_vertical;
        } else if (std.mem.eql(u8, pattern_str, "circular")) {
            return .circular;
        } else if (std.mem.eql(u8, pattern_str, "random")) {
            return .random;
        }
        return .random; // Default
    }

    fn parseEnemyType(type_str: []const u8) EnemySpawnerComp.EnemyType {
        if (std.mem.eql(u8, type_str, "mouse")) {
            return .mouse;
        } else if (std.mem.eql(u8, type_str, "rabbit")) {
            return .rabbit;
        } else if (std.mem.eql(u8, type_str, "sheep")) {
            return .sheep;
        } else if (std.mem.eql(u8, type_str, "wolf")) {
            return .wolf;
        } else if (std.mem.eql(u8, type_str, "lizard")) {
            return .lizard;
        }
        return .mouse; // Default
    }

    fn parseMovementPattern(pattern_str: []const u8) EnemySpawnerComp.MovementPatternType {
        if (std.mem.eql(u8, pattern_str, "tracking")) {
            return .tracking;
        } else if (std.mem.eql(u8, pattern_str, "circular")) {
            return .circular;
        } else if (std.mem.eql(u8, pattern_str, "patrol")) {
            return .patrol;
        } else if (std.mem.eql(u8, pattern_str, "stationary")) {
            return .stationary;
        }
        return .stationary; // Default
    }

    /// Create a default spawner manually
    pub fn createDefaultSpawner(
        world: *WorldMod.World,
        pattern: EnemySpawnerComp.EnemySpawner.SpawnPattern,
        center_x: f32,
        center_y: f32,
        spawn_interval: f32,
        max_enemies: u32,
        start_time: f32,
    ) !void {
        const spawner_entity = world.create();
        try world.spawner_store.set(spawner_entity, .{
            .pattern = pattern,
            .enemy_type = .mouse,
            .start_time = start_time,
            .end_time = -1.0,
            .spawn_interval = spawn_interval,
            .max_enemies = max_enemies,
            .enemies_per_spawn = 3,
            .center_x = center_x,
            .center_y = center_y,
            .radius = 150.0,
            .width = 300.0,
            .height = 300.0,
            .time_until_next_spawn = spawn_interval,
            .enabled = true,
        });
    }
};
