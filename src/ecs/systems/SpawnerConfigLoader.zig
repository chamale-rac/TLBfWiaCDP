const std = @import("std");
const WorldMod = @import("../World.zig");
const EnemySpawnerComp = @import("../components/EnemySpawner.zig");
const IntGridComp = @import("../components/IntGrid.zig");

const Difficulty = EnemySpawnerComp.EnemySpawner.Difficulty;
const SpawnPattern = EnemySpawnerComp.EnemySpawner.SpawnPattern;

const TileCoord = struct { x: i32, y: i32 };
const WorldPos = struct { x: f32, y: f32 };

const TileContext = struct {
    tile_size_world: f32,
    width: i32,
    height: i32,
    world_width: f32,
    world_height: f32,
    intgrid: *const IntGridComp.IntGrid,
};

const SpawnDimensions = struct {
    width: f32,
    height: f32,
    radius: f32,
};

const Placement = struct {
    center_x: f32,
    center_y: f32,
    dims: SpawnDimensions,
};

const AssignedPosition = struct {
    pos: WorldPos,
    difficulty: Difficulty,
};

const SpawnerDefinition = struct {
    pattern: SpawnPattern,
    enemy_type: EnemySpawnerComp.EnemyType,
    movement_pattern: EnemySpawnerComp.MovementPatternType,
    movement_speed_min: f32,
    movement_speed_max: f32,
    tracking_lerp: f32,
    orbit_radius: f32,
    orbit_speed: f32,
    orbit_clockwise: bool,
    patrol_pause: f32,
    patrol_loop: bool,
    start_time: f32,
    end_time: f32,
    spawn_interval: f32,
    max_enemies: u32,
    enemies_per_spawn: u32,
    enabled: bool,
    difficulty: Difficulty,
    width_override: ?f32,
    height_override: ?f32,
    radius_override: ?f32,
    center_override: ?WorldPos,
};

const DifficultyRule = struct {
    min_distance_tiles: f32,
    width_tiles: f32,
    height_tiles: f32,
    radius_tiles: f32,
};

pub const SpawnerConfigLoader = struct {
    pub fn loadFromFile(
        world: *WorldMod.World,
        allocator: std.mem.Allocator,
        file_path: []const u8,
        seed: u64,
    ) !void {
        const tile_ctx = try buildTileContext(world);
        var definitions = try parseDefinitions(allocator, file_path);
        defer definitions.deinit(allocator);

        try assignAndCreateSpawners(world, allocator, tile_ctx, definitions.items, seed);
    }

    fn buildTileContext(world: *WorldMod.World) !TileContext {
        var tile_it = world.tilemap_store.iterator();
        const entry = tile_it.next() orelse return error.MissingTilemap;
        const tilemap = entry.value_ptr;
        const entity = entry.key_ptr.*;
        const intgrid = world.intgrid_store.getPtr(entity) orelse return error.MissingIntGrid;

        const tile_size_world = @as(f32, @floatFromInt(tilemap.tile_size)) * tilemap.scale;
        return .{
            .tile_size_world = tile_size_world,
            .width = tilemap.width,
            .height = tilemap.height,
            .world_width = tile_size_world * @as(f32, @floatFromInt(tilemap.width)),
            .world_height = tile_size_world * @as(f32, @floatFromInt(tilemap.height)),
            .intgrid = intgrid,
        };
    }

    fn parseDefinitions(allocator: std.mem.Allocator, file_path: []const u8) !std.ArrayListUnmanaged(SpawnerDefinition) {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        _ = try file.readAll(buffer);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const spawners_array = root.get("spawners") orelse return error.InvalidSpawnerConfig;

        var list = std.ArrayListUnmanaged(SpawnerDefinition){};
        const items = spawners_array.array.items;

        for (items) |spawner_json| {
            const obj = spawner_json.object;
            try list.append(allocator, parseDefinition(obj));
        }

        return list;
    }

    fn parseDefinition(obj: std.json.ObjectMap) SpawnerDefinition {
        const pattern = parsePattern(if (obj.get("pattern")) |val| val.string else "random");
        const enemy_type = parseEnemyType(if (obj.get("enemy_type")) |val| val.string else "mouse");
        const movement_pattern = if (obj.get("movement_pattern")) |mp| parseMovementPattern(mp.string) else .stationary;

        const start_time = toF32(obj.get("start_time").?);
        const end_time = toF32(obj.get("end_time").?);
        const spawn_interval = toF32(obj.get("spawn_interval").?);
        const max_enemies = toU32(obj.get("max_enemies").?);
        const enemies_per_spawn = toU32(obj.get("enemies_per_spawn").?);

        const center_override = blk: {
            const maybe_x = obj.get("center_x");
            const maybe_y = obj.get("center_y");
            if (maybe_x != null and maybe_y != null) {
                break :blk WorldPos{
                    .x = toF32(maybe_x.?),
                    .y = toF32(maybe_y.?),
                };
            }
            break :blk null;
        };

        return .{
            .pattern = pattern,
            .enemy_type = enemy_type,
            .movement_pattern = movement_pattern,
            .movement_speed_min = if (obj.get("movement_speed_min")) |val| toF32(val) else 40.0,
            .movement_speed_max = if (obj.get("movement_speed_max")) |val| toF32(val) else 60.0,
            .tracking_lerp = if (obj.get("tracking_lerp")) |val| toF32(val) else 2.0,
            .orbit_radius = if (obj.get("orbit_radius")) |val| toF32(val) else 100.0,
            .orbit_speed = if (obj.get("orbit_speed")) |val| toF32(val) else 1.0,
            .orbit_clockwise = if (obj.get("orbit_clockwise")) |val| val.bool else true,
            .patrol_pause = if (obj.get("patrol_pause")) |val| toF32(val) else 0.0,
            .patrol_loop = if (obj.get("patrol_loop")) |val| val.bool else true,
            .start_time = start_time,
            .end_time = end_time,
            .spawn_interval = spawn_interval,
            .max_enemies = max_enemies,
            .enemies_per_spawn = enemies_per_spawn,
            .enabled = if (obj.get("enabled")) |val| val.bool else true,
            .difficulty = if (obj.get("difficulty")) |val| parseDifficulty(val.string) else .medium,
            .width_override = if (obj.get("width")) |val| toF32(val) else null,
            .height_override = if (obj.get("height")) |val| toF32(val) else null,
            .radius_override = if (obj.get("radius")) |val| toF32(val) else null,
            .center_override = center_override,
        };
    }

    fn assignAndCreateSpawners(
        world: *WorldMod.World,
        allocator: std.mem.Allocator,
        ctx: TileContext,
        defs: []const SpawnerDefinition,
        seed: u64,
    ) !void {
        var walkable_tiles = try collectWalkableTiles(allocator, ctx);
        defer walkable_tiles.deinit(allocator);

        var assigned_positions = std.ArrayListUnmanaged(AssignedPosition){};
        defer assigned_positions.deinit(allocator);

        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        const order = [_]Difficulty{ .easy, .medium, .hard, .extreme };

        for (order) |diff| {
            var idx: usize = 0;
            while (idx < defs.len) : (idx += 1) {
                const def = defs[idx];
                if (def.difficulty != diff) continue;

                const placement = determinePlacement(def, ctx, walkable_tiles.items, assigned_positions.items, random) catch |err| {
                    std.debug.print("Warning: failed to auto-place spawner ({any}) - falling back to map center\n", .{err});
                    const dims = deriveDimensions(def, ctx.tile_size_world, difficultyRule(def.difficulty));
                    const fallback = Placement{
                        .center_x = ctx.world_width / 2.0,
                        .center_y = ctx.world_height / 2.0,
                        .dims = dims,
                    };
                    try createSpawner(world, def, fallback);
                    continue;
                };

                try assigned_positions.append(allocator, .{
                    .pos = .{ .x = placement.center_x, .y = placement.center_y },
                    .difficulty = def.difficulty,
                });

                try createSpawner(world, def, placement);
            }
        }
    }

    fn determinePlacement(
        def: SpawnerDefinition,
        ctx: TileContext,
        candidates: []const TileCoord,
        assigned: []const AssignedPosition,
        random: std.Random,
    ) !Placement {
        const rule = difficultyRule(def.difficulty);
        const dims = deriveDimensions(def, ctx.tile_size_world, rule);

        if (def.center_override) |manual_center| {
            return .{ .center_x = manual_center.x, .center_y = manual_center.y, .dims = dims };
        }

        const margin = computeMargins(def.pattern, dims, ctx.tile_size_world);
        const tile = try pickTileForSpawner(ctx, candidates, assigned, def.difficulty, rule.min_distance_tiles * ctx.tile_size_world, margin, random);
        const center = tileToWorld(tile, ctx.tile_size_world);

        return .{
            .center_x = center.x,
            .center_y = center.y,
            .dims = dims,
        };
    }

    fn deriveDimensions(def: SpawnerDefinition, tile_size_world: f32, rule: DifficultyRule) SpawnDimensions {
        return .{
            .width = def.width_override orelse rule.width_tiles * tile_size_world,
            .height = def.height_override orelse rule.height_tiles * tile_size_world,
            .radius = def.radius_override orelse rule.radius_tiles * tile_size_world,
        };
    }

    fn pickTileForSpawner(
        ctx: TileContext,
        candidates: []const TileCoord,
        assigned: []const AssignedPosition,
        difficulty: Difficulty,
        min_distance_world: f32,
        margin: TileCoord,
        random: std.Random,
    ) !TileCoord {
        if (candidates.len == 0) return error.NoWalkableTiles;

        var current_distance = min_distance_world;
        var pass: usize = 0;
        const attempts_per_pass = @max(@min(candidates.len * 2, 8000), 512);

        while (pass < 3) : (pass += 1) {
            var attempt: usize = 0;
            while (attempt < attempts_per_pass) : (attempt += 1) {
                const tile = candidates[random.intRangeAtMost(usize, 0, candidates.len - 1)];
                if (!respectsMargins(tile, ctx, margin)) continue;

                const world_pos = tileToWorld(tile, ctx.tile_size_world);
                if (!satisfiesDistance(world_pos, assigned, difficulty, current_distance)) continue;

                return tile;
            }
            current_distance *= 0.75;
        }

        return error.CouldNotAssignSpawn;
    }

    fn satisfiesDistance(
        candidate: WorldPos,
        assigned: []const AssignedPosition,
        difficulty: Difficulty,
        same_tier_requirement: f32,
    ) bool {
        const base_cross_tier: f32 = 140.0;
        const same_tier_sq = same_tier_requirement * same_tier_requirement;
        const base_cross_tier_sq = base_cross_tier * base_cross_tier;

        for (assigned) |existing| {
            const dx = candidate.x - existing.pos.x;
            const dy = candidate.y - existing.pos.y;
            const dist_sq = dx * dx + dy * dy;

            const threshold_sq = if (existing.difficulty == difficulty)
                same_tier_sq
            else
                base_cross_tier_sq;

            if (dist_sq < threshold_sq) {
                return false;
            }
        }
        return true;
    }

    fn computeMargins(pattern: SpawnPattern, dims: SpawnDimensions, tile_size_world: f32) TileCoord {
        const width_tiles = if (dims.width > 0) dims.width / tile_size_world else 0;
        const height_tiles = if (dims.height > 0) dims.height / tile_size_world else 0;
        const radius_tiles = if (dims.radius > 0) dims.radius / tile_size_world else 0;

        var margin_x: f32 = 1.0;
        var margin_y: f32 = 1.0;

        switch (pattern) {
            .line_horizontal => {
                margin_x = width_tiles / 2.0 + 1.0;
                margin_y = 1.0;
            },
            .line_vertical => {
                margin_x = 1.0;
                margin_y = height_tiles / 2.0 + 1.0;
            },
            .circular => {
                margin_x = radius_tiles + 1.0;
                margin_y = radius_tiles + 1.0;
            },
            .random => {
                margin_x = width_tiles / 2.0 + 1.0;
                margin_y = height_tiles / 2.0 + 1.0;
            },
        }

        var margin_x_i32 = @as(i32, @intFromFloat(@ceil(margin_x)));
        var margin_y_i32 = @as(i32, @intFromFloat(@ceil(margin_y)));
        if (margin_x_i32 < 0) margin_x_i32 = 0;
        if (margin_y_i32 < 0) margin_y_i32 = 0;

        return .{
            .x = margin_x_i32,
            .y = margin_y_i32,
        };
    }

    fn respectsMargins(tile: TileCoord, ctx: TileContext, margin: TileCoord) bool {
        const margin_x = @min(margin.x, @divTrunc(ctx.width, 2));
        const margin_y = @min(margin.y, @divTrunc(ctx.height, 2));
        if (tile.x < margin_x or tile.x >= ctx.width - margin_x) return false;
        if (tile.y < margin_y or tile.y >= ctx.height - margin_y) return false;
        return true;
    }

    fn tileToWorld(tile: TileCoord, tile_size_world: f32) WorldPos {
        return .{
            .x = (@as(f32, @floatFromInt(tile.x)) + 0.5) * tile_size_world,
            .y = (@as(f32, @floatFromInt(tile.y)) + 0.5) * tile_size_world,
        };
    }

    fn collectWalkableTiles(allocator: std.mem.Allocator, ctx: TileContext) !std.ArrayListUnmanaged(TileCoord) {
        var list = std.ArrayListUnmanaged(TileCoord){};

        var y: i32 = 0;
        while (y < ctx.height) : (y += 1) {
            var x: i32 = 0;
            while (x < ctx.width) : (x += 1) {
                if (ctx.intgrid.isWalkable(x, y)) {
                    try list.append(allocator, .{ .x = x, .y = y });
                }
            }
        }

        if (list.items.len == 0) return error.NoWalkableTiles;
        return list;
    }

    fn createSpawner(world: *WorldMod.World, def: SpawnerDefinition, placement: Placement) !void {
        const spawner_entity = world.create();
        try world.spawner_store.set(spawner_entity, .{
            .pattern = def.pattern,
            .enemy_type = def.enemy_type,
            .difficulty = def.difficulty,
            .movement_pattern = def.movement_pattern,
            .movement_speed_min = def.movement_speed_min,
            .movement_speed_max = def.movement_speed_max,
            .tracking_lerp = def.tracking_lerp,
            .orbit_radius = def.orbit_radius,
            .orbit_speed = def.orbit_speed,
            .orbit_clockwise = def.orbit_clockwise,
            .patrol_pause = def.patrol_pause,
            .patrol_loop = def.patrol_loop,
            .start_time = def.start_time,
            .end_time = def.end_time,
            .spawn_interval = def.spawn_interval,
            .max_enemies = def.max_enemies,
            .enemies_per_spawn = def.enemies_per_spawn,
            .center_x = placement.center_x,
            .center_y = placement.center_y,
            .radius = placement.dims.radius,
            .width = placement.dims.width,
            .height = placement.dims.height,
            .time_until_next_spawn = def.spawn_interval,
            .enabled = def.enabled,
        });
    }

    fn parsePattern(pattern_str: []const u8) SpawnPattern {
        if (std.mem.eql(u8, pattern_str, "line_horizontal")) return .line_horizontal;
        if (std.mem.eql(u8, pattern_str, "line_vertical")) return .line_vertical;
        if (std.mem.eql(u8, pattern_str, "circular")) return .circular;
        return .random;
    }

    fn parseEnemyType(type_str: []const u8) EnemySpawnerComp.EnemyType {
        if (std.mem.eql(u8, type_str, "mouse")) return .mouse;
        if (std.mem.eql(u8, type_str, "rabbit")) return .rabbit;
        if (std.mem.eql(u8, type_str, "sheep")) return .sheep;
        if (std.mem.eql(u8, type_str, "wolf")) return .wolf;
        if (std.mem.eql(u8, type_str, "lizard")) return .lizard;
        return .mouse;
    }

    fn parseMovementPattern(pattern_str: []const u8) EnemySpawnerComp.MovementPatternType {
        if (std.mem.eql(u8, pattern_str, "tracking")) return .tracking;
        if (std.mem.eql(u8, pattern_str, "circular")) return .circular;
        if (std.mem.eql(u8, pattern_str, "patrol")) return .patrol;
        if (std.mem.eql(u8, pattern_str, "stationary")) return .stationary;
        return .stationary;
    }

    fn parseDifficulty(diff_str: []const u8) Difficulty {
        if (std.mem.eql(u8, diff_str, "easy")) return .easy;
        if (std.mem.eql(u8, diff_str, "medium")) return .medium;
        if (std.mem.eql(u8, diff_str, "hard")) return .hard;
        if (std.mem.eql(u8, diff_str, "extreme")) return .extreme;
        return .medium;
    }

    fn toF32(value: std.json.Value) f32 {
        return switch (value) {
            .float => @floatCast(value.float),
            .integer => @floatFromInt(value.integer),
            else => 0.0,
        };
    }

    fn toU32(value: std.json.Value) u32 {
        return switch (value) {
            .integer => @intCast(value.integer),
            .float => @intFromFloat(value.float),
            else => 0,
        };
    }

    fn difficultyRule(difficulty: Difficulty) DifficultyRule {
        return switch (difficulty) {
            .easy => .{ .min_distance_tiles = 30.0, .width_tiles = 12.0, .height_tiles = 9.0, .radius_tiles = 7.0 },
            .medium => .{ .min_distance_tiles = 24.0, .width_tiles = 10.0, .height_tiles = 8.0, .radius_tiles = 6.0 },
            .hard => .{ .min_distance_tiles = 20.0, .width_tiles = 8.0, .height_tiles = 6.0, .radius_tiles = 5.0 },
            .extreme => .{ .min_distance_tiles = 16.0, .width_tiles = 7.0, .height_tiles = 5.0, .radius_tiles = 4.0 },
        };
    }

    /// Create a default spawner manually (used when config fails to load)
    pub fn createDefaultSpawner(
        world: *WorldMod.World,
        pattern: SpawnPattern,
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
            .difficulty = .medium,
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
