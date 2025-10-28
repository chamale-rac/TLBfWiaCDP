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

            const spawner_entity = world.create();
            try world.spawner_store.set(spawner_entity, .{
                .pattern = pattern,
                .enemy_type = spawner_obj.get("enemy_type").?.string,
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

    /// Create a default spawner manually
    pub fn createDefaultSpawner(
        world: *WorldMod.World,
        pattern: EnemySpawnerComp.EnemySpawner.SpawnPattern,
        center_x: f32,
        center_y: f32,
        spawn_interval: f32,
        max_enemies: u32,
    ) !void {
        const spawner_entity = world.create();
        try world.spawner_store.set(spawner_entity, .{
            .pattern = pattern,
            .enemy_type = "mouse",
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
