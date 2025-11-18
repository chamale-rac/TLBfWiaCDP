const std = @import("std");
const WorldMod = @import("../World.zig");
const EnemySpawnerComp = @import("../components/EnemySpawner.zig");
const TilemapComp = @import("../components/TileMap.zig");
const IntGridComp = @import("../components/IntGrid.zig");

pub const SpawnerConfigLoader = struct {
    pub const DistributionConfig = struct {
        seed: u64 = 1337,
        max_spawners: usize = 24,
        min_distance_tiles: i32 = 10,
        random_region_tiles: f32 = 8.0,
        line_length_tiles: f32 = 10.0,
        circular_radius_tiles: f32 = 6.0,
        base_spawn_interval: f32 = 6.0,
        base_max_enemies: u32 = 6,
        base_enemies_per_spawn: u32 = 1,
        pattern_weights: PatternWeights = .{},
    };

    pub const PatternWeights = struct {
        random: f32 = 1.0,
        circular: f32 = 0.4,
        line_horizontal: f32 = 0.3,
        line_vertical: f32 = 0.3,
    };

    const Position = struct {
        x: i32,
        y: i32,
    };

    const DistributionContext = struct {
        tilemap_entity: WorldMod.Entity,
        tilemap: *TilemapComp.Tilemap,
        intgrid: *IntGridComp.IntGrid,
    };

    pub fn generateDistributedSpawners(world: *WorldMod.World, config: DistributionConfig) !void {
        const ctx = try gatherContext(world);

        var walkable_positions = std.ArrayList(Position).init(world.allocator);
        defer walkable_positions.deinit();

        var y: i32 = 0;
        while (y < ctx.intgrid.height) : (y += 1) {
            var x: i32 = 0;
            while (x < ctx.intgrid.width) : (x += 1) {
                if (!ctx.intgrid.isWalkable(x, y)) continue;
                try walkable_positions.append(.{ .x = x, .y = y });
            }
        }

        if (walkable_positions.items.len == 0) {
            return error.NoWalkableTiles;
        }

        var prng = std.Random.DefaultPrng.init(config.seed);
        const random = prng.random();
        shuffle(random, walkable_positions.items);

        var placed_positions = std.ArrayList(Position).init(world.allocator);
        defer placed_positions.deinit();

        for (walkable_positions.items) |pos| {
            if (placed_positions.items.len >= config.max_spawners) break;
            if (!isFarEnough(pos, placed_positions.items, config.min_distance_tiles)) continue;

            try createSpawner(world, ctx, pos, random, config);
            try placed_positions.append(pos);
        }
    }

    fn gatherContext(world: *WorldMod.World) !DistributionContext {
        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            const entity = entry.key_ptr.*;
            if (world.intgrid_store.getPtr(entity)) |intgrid| {
                return .{
                    .tilemap_entity = entity,
                    .tilemap = entry.value_ptr,
                    .intgrid = intgrid,
                };
            }
        }

        return error.MissingTilemapOrIntGrid;
    }

    fn shuffle(random: std.Random, items: []Position) void {
        if (items.len <= 1) return;

        var i: usize = items.len;
        while (i > 1) {
            const j = random.intRangeLessThan(usize, 0, i);
            std.mem.swap(Position, &items[i - 1], &items[j]);
            i -= 1;
        }
    }

    fn isFarEnough(pos: Position, placed: []const Position, min_distance: i32) bool {
        if (placed.len == 0 or min_distance <= 0) return true;
        const min_dist_sq = @as(i32, min_distance) * @as(i32, min_distance);

        for (placed) |other| {
            const dx = pos.x - other.x;
            const dy = pos.y - other.y;
            if ((dx * dx + dy * dy) < min_dist_sq) {
                return false;
            }
        }
        return true;
    }

    fn createSpawner(
        world: *WorldMod.World,
        ctx: DistributionContext,
        tile_pos: Position,
        random: std.Random,
        config: DistributionConfig,
    ) !void {
        const pattern = pickPattern(random, config.pattern_weights);
        const tile_size = @as(f32, @floatFromInt(ctx.tilemap.tile_size)) * ctx.tilemap.scale;

        const center_x = (@as(f32, @floatFromInt(tile_pos.x)) + 0.5) * tile_size;
        const center_y = (@as(f32, @floatFromInt(tile_pos.y)) + 0.5) * tile_size;

        var spawn_width = tile_size * config.random_region_tiles;
        var spawn_height = spawn_width;
        var spawn_radius = tile_size * config.circular_radius_tiles;

        switch (pattern) {
            .random => {
                spawn_radius = spawn_width * 0.5;
            },
            .circular => {
                spawn_width = spawn_radius * 2.0;
                spawn_height = spawn_radius * 2.0;
            },
            .line_horizontal => {
                spawn_width = tile_size * config.line_length_tiles;
                spawn_height = tile_size * 2.5;
                spawn_radius = spawn_width * 0.5;
            },
            .line_vertical => {
                spawn_width = tile_size * 2.5;
                spawn_height = tile_size * config.line_length_tiles;
                spawn_radius = spawn_height * 0.5;
            },
        }

        const spawner_entity = world.create();
        try world.spawner_store.set(spawner_entity, .{
            .pattern = pattern,
            .movement_pattern = .stationary,
            .center_x = center_x,
            .center_y = center_y,
            .width = spawn_width,
            .height = spawn_height,
            .radius = spawn_radius,
            .spawn_interval = config.base_spawn_interval,
            .time_until_next_spawn = config.base_spawn_interval,
            .max_enemies = config.base_max_enemies,
            .enemies_per_spawn = config.base_enemies_per_spawn,
            .start_time = 0.0,
            .end_time = -1.0,
            .enabled = true,
        });
    }

    fn pickPattern(random: std.Random, weights: PatternWeights) EnemySpawnerComp.EnemySpawner.SpawnPattern {
        const w_random = if (weights.random > 0.0) weights.random else 0.0;
        const w_circular = if (weights.circular > 0.0) weights.circular else 0.0;
        const w_hline = if (weights.line_horizontal > 0.0) weights.line_horizontal else 0.0;
        const w_vline = if (weights.line_vertical > 0.0) weights.line_vertical else 0.0;

        const total = w_random + w_circular + w_hline + w_vline;
        if (total <= 0.0) return .random;

        const pick = random.float(f32) * total;
        if (pick < w_random) return .random;
        if (pick < w_random + w_circular) return .circular;
        if (pick < w_random + w_circular + w_hline) return .line_horizontal;
        return .line_vertical;
    }
};
