const std = @import("std");
const WorldMod = @import("../World.zig");
const SpecialTilesMod = @import("../components/SpecialTiles.zig");
const IntGridMod = @import("../components/IntGrid.zig");

pub const SpecialTilesConfig = struct {
    seed: u64 = 12345,
    // Frequency is the chance (0.0 to 1.0) that a NEW SEQUENCE will start at each walkable tile
    slowdown_frequency: f32 = 0.04,
    speedup_frequency: f32 = 0.04,
    push_frequency: f32 = 0.015,
    // Max consecutive tiles - actual length is random from 1 to max_join
    // Direction picks randomly at EACH step, creating wandering paths
    slowdown_max_join: i32 = 4,
    speedup_max_join: i32 = 7,
    push_max_join: i32 = 1,
    // Min distance that each tile in a sequence must have from ALL already placed tiles of same type
    min_distance: i32 = 4,
};

pub const SpecialTilesGenerationSystem = struct {
    pub fn generateFromTilemap(world: *WorldMod.World, config: SpecialTilesConfig) !void {
        // Find the intgrid entity (should only be one)
        var intgrid_it = world.intgrid_store.iterator();
        const intgrid_entry = intgrid_it.next() orelse return;
        const intgrid = intgrid_entry.value_ptr;

        // Create special tiles entity
        const special_tiles_entity = world.create();
        var special_tiles = try SpecialTilesMod.SpecialTiles.init(
            world.allocator,
            intgrid.width,
            intgrid.height,
        );

        // Random number generator
        var prng = std.Random.DefaultPrng.init(config.seed);
        const random = prng.random();

        // Track ALL placed positions for min_distance enforcement
        var slowdown_positions = std.ArrayListUnmanaged(Position){};
        defer slowdown_positions.deinit(world.allocator);
        var speedup_positions = std.ArrayListUnmanaged(Position){};
        defer speedup_positions.deinit(world.allocator);
        var push_positions = std.ArrayListUnmanaged(Position){};
        defer push_positions.deinit(world.allocator);

        // Grid to track occupied positions (any type)
        var occupied = std.ArrayListUnmanaged(bool){};
        defer occupied.deinit(world.allocator);
        try occupied.ensureTotalCapacity(world.allocator, @intCast(intgrid.width * intgrid.height));
        occupied.items.len = @intCast(intgrid.width * intgrid.height);
        @memset(occupied.items, false);

        // Iterate through all tiles and try to start sequences
        var y: i32 = 0;
        while (y < intgrid.height) : (y += 1) {
            var x: i32 = 0;
            while (x < intgrid.width) : (x += 1) {
                // Skip if not walkable or already occupied
                if (!intgrid.isWalkable(x, y)) continue;
                const idx = @as(usize, @intCast(y * intgrid.width + x));
                if (occupied.items[idx]) continue;

                const pos = Position{ .x = x, .y = y };

                // Try to start a slowdown sequence
                if (random.float(f32) < config.slowdown_frequency and
                    isMinDistanceOk(pos, slowdown_positions.items, config.min_distance))
                {
                    try placeSequence(
                        world.allocator,
                        &special_tiles,
                        intgrid,
                        &occupied,
                        &slowdown_positions,
                        random,
                        x,
                        y,
                        config.slowdown_max_join,
                        config.min_distance,
                        .slowdown,
                    );
                    continue;
                }

                // Try to start a speedup sequence
                if (random.float(f32) < config.speedup_frequency and
                    isMinDistanceOk(pos, speedup_positions.items, config.min_distance))
                {
                    try placeSequence(
                        world.allocator,
                        &special_tiles,
                        intgrid,
                        &occupied,
                        &speedup_positions,
                        random,
                        x,
                        y,
                        config.speedup_max_join,
                        config.min_distance,
                        .speedup,
                    );
                    continue;
                }

                // Try to start a push sequence
                if (random.float(f32) < config.push_frequency and
                    isMinDistanceOk(pos, push_positions.items, config.min_distance))
                {
                    try placeSequence(
                        world.allocator,
                        &special_tiles,
                        intgrid,
                        &occupied,
                        &push_positions,
                        random,
                        x,
                        y,
                        config.push_max_join,
                        config.min_distance,
                        .push_teleport,
                    );
                    continue;
                }
            }
        }

        try world.special_tiles_store.set(special_tiles_entity, special_tiles);
    }

    /// Place a sequence of tiles with random walk behavior
    /// - Length is random from 1 to max_length
    /// - Direction picks randomly at EACH step (up/down/left/right)
    /// - Only the FIRST tile must respect min_distance from other sequences
    /// - Stops if hitting non-walkable, occupied, or bounds
    fn placeSequence(
        allocator: std.mem.Allocator,
        special_tiles: *SpecialTilesMod.SpecialTiles,
        intgrid: *const IntGridMod.IntGrid,
        occupied: *std.ArrayListUnmanaged(bool),
        type_positions: *std.ArrayListUnmanaged(Position),
        random: std.Random,
        start_x: i32,
        start_y: i32,
        max_length: i32,
        min_distance: i32,
        tile_type: SpecialTilesMod.TileType,
    ) !void {
        // Random sequence length from 1 to max_length
        const sequence_length = if (max_length > 1)
            random.intRangeAtMost(i32, 1, max_length)
        else
            1;

        const directions = [_]struct { dx: i32, dy: i32 }{
            .{ .dx = 1, .dy = 0 }, // right
            .{ .dx = -1, .dy = 0 }, // left
            .{ .dx = 0, .dy = 1 }, // down
            .{ .dx = 0, .dy = -1 }, // up
        };

        var current_x = start_x;
        var current_y = start_y;
        var placed: i32 = 0;

        // Remember how many tiles were already placed before this sequence
        const positions_before_sequence = type_positions.items.len;

        while (placed < sequence_length) {
            // Check if current position is valid
            if (current_x < 0 or current_x >= intgrid.width or
                current_y < 0 or current_y >= intgrid.height) break;

            if (!intgrid.isWalkable(current_x, current_y)) break;

            const idx = @as(usize, @intCast(current_y * intgrid.width + current_x));
            if (occupied.items[idx]) break;

            const pos = Position{ .x = current_x, .y = current_y };

            // Only check min_distance against tiles from OTHER sequences (not current sequence)
            if (!isMinDistanceOk(pos, type_positions.items[0..positions_before_sequence], min_distance)) break;

            // Place the tile
            try special_tiles.set(allocator, current_x, current_y, tile_type);
            occupied.items[idx] = true;
            try type_positions.append(allocator, pos);
            placed += 1;

            // Pick a random direction for the next step
            const dir = directions[random.intRangeAtMost(usize, 0, 3)];
            current_x += dir.dx;
            current_y += dir.dy;
        }
    }

    /// Check if position respects min_distance from all positions in the list
    fn isMinDistanceOk(pos: Position, positions: []const Position, min_distance: i32) bool {
        if (min_distance <= 0) return true;

        for (positions) |other_pos| {
            const dx = pos.x - other_pos.x;
            const dy = pos.y - other_pos.y;
            const dist_squared = dx * dx + dy * dy;
            const min_dist_squared = min_distance * min_distance;
            if (dist_squared < min_dist_squared) {
                return false;
            }
        }
        return true;
    }
};

const Position = struct {
    x: i32,
    y: i32,
};
