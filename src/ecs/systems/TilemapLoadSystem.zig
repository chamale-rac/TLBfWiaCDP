const std = @import("std");
const WorldMod = @import("../World.zig");
const Assets = @import("../../assets/Assets.zig");
const TilemapComp = @import("../components/TileMap.zig");
const ZIndex = @import("../components/ZIndex.zig");

pub const TilemapLoadSystem = struct {
    pub fn loadDemo(world: *WorldMod.World, assets: *Assets.Assets) !void {
        const width: i32 = 10;
        const height: i32 = 10;
        const tile_size: i32 = 16;
        const scale: f32 = 5.0;

        // 10x10 map from the task description (0 water, 1 grass)
        const data = [10][10]u8{
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
            .{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
            .{ 0, 1, 0, 0, 0, 0, 0, 0, 1, 0 },
            .{ 0, 1, 0, 0, 0, 0, 0, 0, 1, 0 },
            .{ 0, 1, 0, 0, 1, 1, 1, 0, 1, 0 },
            .{ 0, 1, 0, 0, 1, 0, 1, 1, 1, 0 },
            .{ 0, 1, 0, 0, 0, 0, 0, 0, 1, 0 },
            .{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
            .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        };

        var tiles = std.ArrayListUnmanaged(TilemapComp.Tile){};

        var y: i32 = 0;
        while (y < height) : (y += 1) {
            var x: i32 = 0;
            while (x < width) : (x += 1) {
                const d: u8 = data[@intCast(y)][@intCast(x)];
                const ttype: TilemapComp.TileType = if (d == 1) .grass else .water;
                try tiles.append(world.allocator, .{
                    .ttype = ttype,
                    .needs_autotiling = (ttype == .grass),
                });
            }
        }

        const e = world.create();
        try world.tilemap_store.set(e, .{
            .width = width,
            .height = height,
            .tile_size = tile_size,
            .scale = scale,
            .water_texture = assets.water,
            .grass_texture = assets.grass,
            .tiles = tiles,
        });

        // Ensure it draws behind sprites
        try world.z_index_store.set(e, .{ .value = -500 });
        _ = ZIndex; // keep import used if z-index is removed later
    }
};
