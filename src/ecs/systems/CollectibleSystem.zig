const std = @import("std");
const WorldMod = @import("../World.zig");
const Assets = @import("../../assets/Assets.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");
const CollectibleComp = @import("../components/Collectible.zig");
const Transform2D = @import("../components/Transform2D.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

const STATIC_FRAMES = [_]i32{ 1 };
const STATIC_FRAME_SLICE = STATIC_FRAMES[0..];
const STATIC_ANIM_SET = AnimatedSprite.AnimationSet{
    .idle = .{ .start_row = 0, .frames = STATIC_FRAME_SLICE },
    .walk = .{ .start_row = 0, .frames = STATIC_FRAME_SLICE },
    .run = .{ .start_row = 0, .frames = STATIC_FRAME_SLICE },
};
const bottle_render_scale: f32 = 0.65;

const Rect = struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

const TileCoord = struct {
    x: i32,
    y: i32,
};

pub const CollectibleSystem = struct {
    pub const Progress = struct {
        total: u32,
        collected: u32 = 0,

        pub fn init(total: u32) Progress {
            return .{ .total = total, .collected = 0 };
        }

        pub fn isComplete(self: Progress) bool {
            return self.total > 0 and self.collected >= self.total;
        }
    };

    pub fn spawnBottles(world: *WorldMod.World, assets: *Assets.Assets, seed: u64, desired_count: u32) !u32 {
        if (desired_count == 0) return 0;

        var tm_it = world.tilemap_store.iterator();
        const tm_entry = tm_it.next() orelse return 0;
        const tilemap = tm_entry.value_ptr.*;

        var walkable = std.array_list.Managed(TileCoord).init(world.allocator);
        defer walkable.deinit();

        if (tilemap.width <= 0 or tilemap.height <= 0) return 0;
        const width_usize: usize = @intCast(tilemap.width);

        var idx: usize = 0;
        while (idx < tilemap.tiles.items.len) : (idx += 1) {
            const tile = tilemap.tiles.items[idx];
            if (tile.ttype == .grass) {
                const tile_x = @as(i32, @intCast(idx % width_usize));
                const tile_y = @as(i32, @intCast(idx / width_usize));
                try walkable.append(.{ .x = tile_x, .y = tile_y });
            }
        }

        if (walkable.items.len == 0) return 0;

        var prng = std.Random.DefaultPrng.init(seed);
        prng.random().shuffle(TileCoord, walkable.items);

        const available: usize = walkable.items.len;
        const spawn_total_usize = @min(@as(usize, @intCast(desired_count)), available);
        if (spawn_total_usize == 0) return 0;

        const cell_size = @as(f32, @floatFromInt(tilemap.tile_size)) * tilemap.scale;
        const texture_width = @as(f32, @floatFromInt(assets.bottle.width));
        const texture_height = @as(f32, @floatFromInt(assets.bottle.height));
        const scaled_width = texture_width * bottle_render_scale;
        const scaled_height = texture_height * bottle_render_scale;
        const offset_x = (cell_size - scaled_width) / 2.0;
        const offset_y = (cell_size - scaled_height) / 2.0;

        var spawned: usize = 0;
        while (spawned < spawn_total_usize) : (spawned += 1) {
            const coord = walkable.items[spawned];
            const world_x = @as(f32, @floatFromInt(coord.x)) * cell_size + offset_x;
            const world_y = @as(f32, @floatFromInt(coord.y)) * cell_size + offset_y;

            const entity = world.create();
            try world.transform_store.set(entity, .{ .x = world_x, .y = world_y });
            try world.sprite_store.set(entity, .{
                .texture = assets.bottle,
                .grid = .{
                    .image_width = assets.bottle.width,
                    .image_height = assets.bottle.height,
                    .frame_width = assets.bottle.width,
                    .frame_height = assets.bottle.height,
                },
                .set = STATIC_ANIM_SET,
                .current = .idle,
                .direction = .back,
                .seconds_per_frame = 1.0,
                .layer = 0,
                .render_scale = bottle_render_scale,
            });
            try world.z_index_store.set(entity, .{ .value = 25 });
            try world.collectible_store.set(entity, .{
                .kind = .bottle,
                .width = scaled_width,
                .height = scaled_height,
            });
        }

        return @intCast(spawn_total_usize);
    }

    pub fn update(world: *WorldMod.World, player_entity: WorldMod.Entity, progress: *Progress) void {
        const player_transform = world.transform_store.get(player_entity) orelse return;
        const player_rect = playerCollisionRect(player_transform);

        var to_remove = std.array_list.Managed(WorldMod.Entity).init(world.allocator);
        defer to_remove.deinit();

        var it = world.collectible_store.iterator();
        while (it.next()) |entry| {
            const entity = entry.key_ptr.*;
            const collectible = entry.value_ptr.*;
            const transform = world.transform_store.get(entity) orelse continue;
            const col_rect = collectibleRect(transform, collectible);

            if (rectsOverlap(player_rect, col_rect)) {
                if (progress.total > 0 and progress.collected < progress.total) {
                    progress.collected += 1;
                }
                to_remove.append(entity) catch {};
            }
        }

        for (to_remove.items) |entity| {
            world.collectible_store.remove(entity);
            world.transform_store.remove(entity);
            world.sprite_store.remove(entity);
            world.z_index_store.remove(entity);
        }
    }
};

fn playerCollisionRect(transform: Transform2D.Transform2D) Rect {
    const cfg = CollisionConfig.CollisionConfig;
    return .{
        .left = transform.x + cfg.WEST_INSET,
        .right = transform.x + cfg.SPRITE_WIDTH - cfg.EAST_INSET,
        .top = transform.y + cfg.NORTH_INSET,
        .bottom = transform.y + cfg.SPRITE_HEIGHT - cfg.SOUTH_INSET,
    };
}

fn collectibleRect(transform: Transform2D.Transform2D, collectible: CollectibleComp.Collectible) Rect {
    return .{
        .left = transform.x,
        .right = transform.x + collectible.width,
        .top = transform.y,
        .bottom = transform.y + collectible.height,
    };
}

fn rectsOverlap(a: Rect, b: Rect) bool {
    return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top;
}

