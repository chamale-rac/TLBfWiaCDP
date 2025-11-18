const std = @import("std");
const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const BottleSystem = struct {
    const pickup_padding: f32 = 18.0;

    pub fn spawnRandomOnGrass(world: *WorldMod.World, rng_seed: u64, count: usize) !void {
        if (count == 0) return;

        var tm_it = world.tilemap_store.iterator();
        const tilemap_entry = tm_it.next() orelse return error.NoTilemapFound;
        const tilemap = tilemap_entry.value_ptr.*;

        const tile_draw_size: f32 = @as(f32, @floatFromInt(tilemap.tile_size)) * tilemap.scale;
        const bottle_radius = tile_draw_size * 0.30;

        var prng = std.rand.DefaultPrng.init(rng_seed);
        const random = prng.random();

        var spawned: usize = 0;
        var attempts: usize = 0;
        const max_attempts = count * 200;

        while (spawned < count and attempts < max_attempts) : (attempts += 1) {
            const rand_x = random.uintLessThan(u32, @intCast(tilemap.width));
            const rand_y = random.uintLessThan(u32, @intCast(tilemap.height));
            const tile_x: i32 = @intCast(rand_x);
            const tile_y: i32 = @intCast(rand_y);

            const tile_idx = tilemap.index(tile_x, tile_y);
            if (tilemap.tiles.items[tile_idx].ttype != .grass) continue;

            const world_x = (@as(f32, @floatFromInt(tile_x)) * tile_draw_size) + tile_draw_size * 0.5;
            const world_y = (@as(f32, @floatFromInt(tile_y)) * tile_draw_size) + tile_draw_size * 0.5;

            if (!isSpotFree(world, world_x, world_y, bottle_radius * 2.0)) continue;

            const entity = world.create();
            try world.bottle_store.set(entity, .{
                .x = world_x,
                .y = world_y,
                .radius = bottle_radius,
                .tint = pickTint(random),
            });
            spawned += 1;
        }

        if (spawned < count) {
            return error.CouldNotPlaceRequestedBottles;
        }
    }

    pub fn update(world: *WorldMod.World, player: WorldMod.Entity) void {
        const player_center = getPlayerCenter(world, player) orelse return;
        var it = world.bottle_store.iterator();
        while (it.next()) |entry| {
            var bottle = entry.value_ptr;
            if (bottle.collected) continue;

            const dx = player_center.x - bottle.x;
            const dy = player_center.y - bottle.y;
            const pickup_radius = bottle.radius + pickup_padding;

            if ((dx * dx) + (dy * dy) <= pickup_radius * pickup_radius) {
                bottle.collected = true;
            }
        }
    }

    pub fn draw(world: *WorldMod.World) void {
        var it = world.bottle_store.iterator();
        while (it.next()) |entry| {
            const bottle = entry.value_ptr.*;
            if (bottle.collected) continue;

            const center_x = @as(i32, @intFromFloat(bottle.x));
            const center_y = @as(i32, @intFromFloat(bottle.y));
            raylib.cdef.DrawCircle(center_x, center_y, bottle.radius, bottle.tint);
            raylib.cdef.DrawCircleLines(center_x, center_y, bottle.radius, raylib.Color{ .r = 255, .g = 255, .b = 255, .a = 200 });
        }
    }

    pub fn getProgress(world: *WorldMod.World) struct { collected: u32, total: u32 } {
        var collected: u32 = 0;
        var total: u32 = 0;
        var it = world.bottle_store.iterator();
        while (it.next()) |entry| {
            const bottle = entry.value_ptr.*;
            total += 1;
            if (bottle.collected) {
                collected += 1;
            }
        }
        return .{ .collected = collected, .total = total };
    }

    pub fn hasWon(world: *WorldMod.World) bool {
        const progress = getProgress(world);
        return progress.total > 0 and progress.collected >= progress.total;
    }

    fn pickTint(random: std.rand.Random) raylib.Color {
        const palette = [_]raylib.Color{
            raylib.Color{ .r = 0, .g = 200, .b = 255, .a = 255 },
            raylib.Color{ .r = 0, .g = 170, .b = 200, .a = 255 },
            raylib.Color{ .r = 0, .g = 220, .b = 180, .a = 255 },
        };
        const idx = random.uintLessThan(u32, palette.len);
        return palette[@intCast(idx)];
    }

    fn getPlayerCenter(world: *WorldMod.World, player: WorldMod.Entity) ?struct { x: f32, y: f32 } {
        if (world.transform_store.get(player)) |transform| {
            return .{
                .x = transform.x + CollisionConfig.CollisionConfig.SPRITE_HALF_WIDTH,
                .y = transform.y + CollisionConfig.CollisionConfig.SPRITE_HALF_HEIGHT,
            };
        }
        return null;
    }

    fn isSpotFree(world: *WorldMod.World, x: f32, y: f32, min_distance: f32) bool {
        const min_sq = min_distance * min_distance;
        var it = world.bottle_store.iterator();
        while (it.next()) |entry| {
            const existing = entry.value_ptr.*;
            const dx = existing.x - x;
            const dy = existing.y - y;
            if ((dx * dx) + (dy * dy) < min_sq) {
                return false;
            }
        }
        return true;
    }
};
