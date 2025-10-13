const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const TilemapComp = @import("../components/TileMap.zig");

pub const TilemapRenderSystem = struct {
    pub fn draw(world: *WorldMod.World) void {
        var it = world.tilemap_store.iterator();
        while (it.next()) |entry| {
            const tm = entry.value_ptr.*;

            const tsize = @as(f32, @floatFromInt(tm.tile_size));
            const scale = tm.scale;
            const draw_size = tsize * scale;

            var y: i32 = 0;
            while (y < tm.height) : (y += 1) {
                var x: i32 = 0;
                while (x < tm.width) : (x += 1) {
                    const idx: usize = tm.index(x, y);
                    const tile = tm.tiles.items[idx];

                    const dest_x = @as(f32, @floatFromInt(x)) * draw_size;
                    const dest_y = @as(f32, @floatFromInt(y)) * draw_size;

                    // Always draw water first for this cell
                    const water_src = raylib.Rectangle{ .x = 0, .y = 0, .width = tsize, .height = tsize };
                    const water_dst = raylib.Rectangle{ .x = dest_x, .y = dest_y, .width = draw_size, .height = draw_size };
                    raylib.cdef.DrawTexturePro(tm.water_texture, water_src, water_dst, .{ .x = 0, .y = 0 }, 0, raylib.Color.white);

                    if (tile.ttype == .grass) {
                        const grass_src = raylib.Rectangle{ .x = @as(f32, @floatFromInt(tile.sx)), .y = @as(f32, @floatFromInt(tile.sy)), .width = tsize, .height = tsize };
                        const grass_dst = raylib.Rectangle{ .x = dest_x, .y = dest_y, .width = draw_size, .height = draw_size };
                        raylib.cdef.DrawTexturePro(tm.grass_texture, grass_src, grass_dst, .{ .x = 0, .y = 0 }, 0, raylib.Color.white);
                    }
                }
            }
        }
    }
};
