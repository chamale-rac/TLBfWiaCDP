const std = @import("std");
const WorldMod = @import("../World.zig");
const IntGridComp = @import("../components/IntGrid.zig");
const TilemapComp = @import("../components/TileMap.zig");

pub const IntGridSystem = struct {
    pub fn setupFromTilemap(world: *WorldMod.World) void {
        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            const tm = entry.value_ptr.*;
            const entity = entry.key_ptr.*;

            // Create IntGrid for this tilemap
            var intgrid = IntGridComp.IntGrid.init(world.allocator, tm.width, tm.height) catch continue;

            // Map tile types to IntGrid values
            var y: i32 = 0;
            while (y < tm.height) : (y += 1) {
                var x: i32 = 0;
                while (x < tm.width) : (x += 1) {
                    const tile_idx = tm.index(x, y);
                    const tile = tm.tiles.items[tile_idx];

                    const intgrid_value: IntGridComp.IntGridValue = switch (tile.ttype) {
                        .grass => .walkable_ground,
                        .water => .non_walkable_water,
                    };

                    intgrid.set(x, y, intgrid_value);
                }
            }

            // Store the IntGrid in the world
            world.intgrid_store.set(entity, intgrid) catch continue;
        }
    }

    pub fn isWalkableAt(world: *WorldMod.World, x: f32, y: f32) bool {
        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            const tm = entry.value_ptr.*;
            const entity = entry.key_ptr.*;

            if (world.intgrid_store.get(entity)) |intgrid| {
                // Convert world coordinates to tile coordinates
                const tile_size = @as(f32, @floatFromInt(tm.tile_size)) * tm.scale;
                const tile_x = @as(i32, @intFromFloat(@floor(x / tile_size)));
                const tile_y = @as(i32, @intFromFloat(@floor(y / tile_size)));

                return intgrid.isWalkable(tile_x, tile_y);
            }
        }
        return false; // No tilemap found, assume non-walkable
    }

    pub fn getTileCoordinates(world: *WorldMod.World, x: f32, y: f32) ?struct { tile_x: i32, tile_y: i32, tile_size: f32 } {
        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            const tm = entry.value_ptr.*;

            // Convert world coordinates to tile coordinates
            const tile_size = @as(f32, @floatFromInt(tm.tile_size)) * tm.scale;
            const tile_x = @as(i32, @intFromFloat(@floor(x / tile_size)));
            const tile_y = @as(i32, @intFromFloat(@floor(y / tile_size)));

            // Check if coordinates are within tilemap bounds
            if (tile_x >= 0 and tile_x < tm.width and tile_y >= 0 and tile_y < tm.height) {
                return .{ .tile_x = tile_x, .tile_y = tile_y, .tile_size = tile_size };
            }
        }
        return null;
    }
};
