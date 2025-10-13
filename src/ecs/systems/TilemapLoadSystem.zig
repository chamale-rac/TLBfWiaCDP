const std = @import("std");
const WorldMod = @import("../World.zig");
const Assets = @import("../../assets/Assets.zig");
const TilemapComp = @import("../components/TileMap.zig");
const fastnoise = @import("fastnoise");
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

    pub fn loadFromNoise(world: *WorldMod.World, assets: *Assets.Assets) !void {
        // Configure noise
        var noise = fastnoise.Noise(f32){
            .noise_type = .simplex, // OpenSimplex2 equivalent in this lib
            .frequency = 0.05,
        };

        // Choose map size to cover window comfortably
        const tile_size: i32 = 16;
        const scale: f32 = 4.0;
        const screen_w: f32 = 960;
        const screen_h: f32 = 540;
        const draw_size = @as(f32, @floatFromInt(tile_size)) * scale;
        const wcalc_f = @ceil(screen_w / draw_size);
        const hcalc_f = @ceil(screen_h / draw_size);
        const wcalc: i32 = @intFromFloat(wcalc_f);
        const hcalc: i32 = @intFromFloat(hcalc_f);
        const width2: i32 = wcalc + 2;
        const height: i32 = hcalc + 2;

        var tiles = std.ArrayListUnmanaged(TilemapComp.Tile){};

        var y: i32 = 0;
        while (y < height) : (y += 1) {
            var x: i32 = 0;
            while (x < width2) : (x += 1) {
                const nx: f32 = @floatFromInt(x);
                const ny: f32 = @floatFromInt(y);
                const v: f32 = noise.genNoise2D(nx, ny);
                const ttype: TilemapComp.TileType = if (v > 0.0) .grass else .water;
                try tiles.append(world.allocator, .{
                    .ttype = ttype,
                    .needs_autotiling = (ttype == .grass),
                });
            }
        }

        const e = world.create();
        try world.tilemap_store.set(e, .{
            .width = width2,
            .height = height,
            .tile_size = tile_size,
            .scale = scale,
            .water_texture = assets.water,
            .grass_texture = assets.grass,
            .tiles = tiles,
        });

        try world.z_index_store.set(e, .{ .value = -500 });
    }
};
