const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const SpecialTilesMod = @import("../components/SpecialTiles.zig");

pub const SpecialTilesRenderSystem = struct {
    pub fn draw(world: *WorldMod.World) void {
        // Get tilemap for tile size information
        var tm_it = world.tilemap_store.iterator();
        const tm_entry = tm_it.next() orelse return;
        const tm = tm_entry.value_ptr.*;

        const tsize = @as(f32, @floatFromInt(tm.tile_size));
        const scale = tm.scale;
        const draw_size = tsize * scale;

        // Iterate through special tiles and draw them
        var special_tiles_it = world.special_tiles_store.iterator();
        while (special_tiles_it.next()) |entry| {
            const special_tiles = entry.value_ptr;

            // Draw each special tile
            for (special_tiles.tiles.items) |tile| {
                const dest_x = @as(f32, @floatFromInt(tile.x)) * draw_size;
                const dest_y = @as(f32, @floatFromInt(tile.y)) * draw_size;

                // Choose color based on tile type
                const overlay_color = switch (tile.tile_type) {
                    .slowdown => raylib.Color{ .r = 135, .g = 206, .b = 235, .a = 180 }, // Sky blue
                    .speedup => raylib.Color{ .r = 255, .g = 255, .b = 0, .a = 180 }, // Yellow
                    .push_teleport => raylib.Color{ .r = 128, .g = 0, .b = 128, .a = 180 }, // Purple
                    .none => continue, // Skip rendering for none
                };

                // Draw colored overlay
                const overlay_rect = raylib.Rectangle{
                    .x = dest_x,
                    .y = dest_y,
                    .width = draw_size,
                    .height = draw_size,
                };
                raylib.cdef.DrawRectangleRec(overlay_rect, overlay_color);

                // Draw border for better visibility
                const border_color = switch (tile.tile_type) {
                    .slowdown => raylib.Color{ .r = 70, .g = 130, .b = 180, .a = 255 }, // Darker sky blue
                    .speedup => raylib.Color{ .r = 200, .g = 200, .b = 0, .a = 255 }, // Darker yellow
                    .push_teleport => raylib.Color{ .r = 75, .g = 0, .b = 130, .a = 255 }, // Darker purple
                    .none => continue,
                };
                raylib.cdef.DrawRectangleLinesEx(overlay_rect, 2.0, border_color);
            }
        }
    }
};
