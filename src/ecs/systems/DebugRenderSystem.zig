const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const IntGridSystem = @import("IntGridSystem.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const DebugRenderSystem = struct {
    show_debug: bool = false,

    pub fn toggle(self: *@This()) void {
        self.show_debug = !self.show_debug;
    }

    pub fn draw(self: *@This(), world: *WorldMod.World) void {
        if (!self.show_debug) return;

        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            const tm = entry.value_ptr.*;
            const entity = entry.key_ptr.*;

            if (world.intgrid_store.get(entity)) |intgrid| {
                const tsize = @as(f32, @floatFromInt(tm.tile_size));
                const scale = tm.scale;
                const draw_size = tsize * scale;

                var y: i32 = 0;
                while (y < tm.height) : (y += 1) {
                    var x: i32 = 0;
                    while (x < tm.width) : (x += 1) {
                        const dest_x = @as(f32, @floatFromInt(x)) * draw_size;
                        const dest_y = @as(f32, @floatFromInt(y)) * draw_size;

                        // Get IntGrid value for this tile
                        const intgrid_value = intgrid.get(x, y);

                        // Choose color based on walkability
                        const overlay_color = switch (intgrid_value) {
                            .walkable_ground => raylib.Color{ .r = 0, .g = 255, .b = 0, .a = 100 }, // Green with opacity
                            .non_walkable_water => raylib.Color{ .r = 255, .g = 0, .b = 0, .a = 100 }, // Red with opacity
                        };

                        // Draw colored overlay
                        const overlay_rect = raylib.Rectangle{ .x = dest_x, .y = dest_y, .width = draw_size, .height = draw_size };
                        raylib.cdef.DrawRectangleRec(overlay_rect, overlay_color);

                        // Draw black border
                        const border_color = raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
                        raylib.cdef.DrawRectangleLinesEx(overlay_rect, 1.0, border_color);
                    }
                }
            }
        }

        // Draw player collision points if debug is enabled
        if (self.show_debug) {
            drawPlayerCollisionPoints(world);
        }
    }

    fn drawPlayerCollisionPoints(world: *WorldMod.World) void {
        // Find player entity and draw collision points
        var vel_it = world.velocity_store.iterator();
        while (vel_it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (world.transform_store.get(e)) |tr| {
                // Get collision points from shared configuration
                const collision_points = CollisionConfig.getDebugCollisionPoints(tr.x, tr.y);

                for (collision_points) |point| {
                    const is_walkable = IntGridSystem.IntGridSystem.isWalkableAt(world, point.x, point.y);
                    const color = if (is_walkable)
                        raylib.Color{ .r = 0, .g = 255, .b = 0, .a = 200 } // Green
                    else
                        raylib.Color{ .r = 255, .g = 0, .b = 0, .a = 200 }; // Red

                    raylib.cdef.DrawCircle(@as(i32, @intFromFloat(point.x)), @as(i32, @intFromFloat(point.y)), 3.0, color);
                }
                break; // Only draw for the first entity with velocity (player)
            }
        }
    }
};
