const raylib = @import("raylib");
const std = @import("std");
const WorldMod = @import("../World.zig");
const IntGridSystem = @import("IntGridSystem.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const DebugRenderSystem = struct {
    show_debug: bool = false,
    show_spawners: bool = true, // Show spawners by default

    pub fn toggle(self: *@This()) void {
        self.show_debug = !self.show_debug;
    }

    pub fn toggleSpawners(self: *@This()) void {
        self.show_spawners = !self.show_spawners;
    }

    pub fn draw(self: *@This(), world: *WorldMod.World) void {
        // Draw spawner zones (visible even when general debug is off)
        if (self.show_spawners) {
            self.drawSpawnerZones(world);
        }

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

    fn drawSpawnerZones(self: *@This(), world: *WorldMod.World) void {
        _ = self;
        var spawner_it = world.spawner_store.iterator();
        while (spawner_it.next()) |entry| {
            const spawner = entry.value_ptr.*;

            const color = spawner.getSpawnColor();
            const center_x: i32 = @intFromFloat(spawner.center_x);
            const center_y: i32 = @intFromFloat(spawner.center_y);

            // Draw based on pattern type
            switch (spawner.pattern) {
                .line_horizontal => {
                    const width: f32 = spawner.width;
                    const left_x: f32 = spawner.center_x - width / 2.0;
                    const right_x: f32 = spawner.center_x + width / 2.0;

                    // Draw horizontal line
                    raylib.cdef.DrawLineEx(raylib.Vector2{ .x = left_x, .y = spawner.center_y }, raylib.Vector2{ .x = right_x, .y = spawner.center_y }, 4.0, color);

                    // Draw end markers
                    raylib.cdef.DrawCircle(@intFromFloat(left_x), center_y, 8.0, color);
                    raylib.cdef.DrawCircle(@intFromFloat(right_x), center_y, 8.0, color);
                },
                .line_vertical => {
                    const height: f32 = spawner.height;
                    const top_y: f32 = spawner.center_y - height / 2.0;
                    const bottom_y: f32 = spawner.center_y + height / 2.0;

                    // Draw vertical line
                    raylib.cdef.DrawLineEx(raylib.Vector2{ .x = spawner.center_x, .y = top_y }, raylib.Vector2{ .x = spawner.center_x, .y = bottom_y }, 4.0, color);

                    // Draw end markers
                    raylib.cdef.DrawCircle(center_x, @intFromFloat(top_y), 8.0, color);
                    raylib.cdef.DrawCircle(center_x, @intFromFloat(bottom_y), 8.0, color);
                },
                .circular => {
                    // Draw circle outline
                    raylib.cdef.DrawCircleLines(center_x, center_y, spawner.radius, color);
                    raylib.cdef.DrawCircleLines(center_x, center_y, spawner.radius + 2.0, color);

                    // Draw center marker
                    raylib.cdef.DrawCircle(center_x, center_y, 6.0, color);
                },
                .random => {
                    const width: f32 = spawner.width;
                    const height: f32 = spawner.height;
                    const left_x: f32 = spawner.center_x - width / 2.0;
                    const top_y: f32 = spawner.center_y - height / 2.0;

                    // Draw rectangle outline
                    const rect = raylib.Rectangle{
                        .x = left_x,
                        .y = top_y,
                        .width = width,
                        .height = height,
                    };
                    raylib.cdef.DrawRectangleLinesEx(rect, 3.0, color);

                    // Draw center marker
                    raylib.cdef.DrawCircle(center_x, center_y, 6.0, color);
                },
            }

            // Draw spawner status text near center
            const text_x = center_x + 10;
            const text_y = center_y - 20;
            var buffer: [64]u8 = undefined;
            const status_text = std.fmt.bufPrintZ(&buffer, "{d}/{d}", .{ spawner.active_enemies, spawner.max_enemies }) catch "?/?";
            raylib.cdef.DrawText(status_text.ptr, text_x, text_y, 16, raylib.Color.white);
        }
    }
};
