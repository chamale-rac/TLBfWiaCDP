const std = @import("std");
const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");

const DrawCommand = struct {
    z: i32,
    x: f32,
    y: f32,
    cmd: union(enum) {
        background: struct {
            texture: raylib.Texture2D,
            repeat: bool,
        },
        sprite: struct {
            texture: raylib.Texture2D,
            src: raylib.Rectangle,
            w: f32,
            h: f32,
            color: raylib.Color,
        },
    },
};

pub const RenderSystem = struct {
    pub fn draw(world: *WorldMod.World) !void {
        var arena = std.heap.ArenaAllocator.init(world.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var commands = std.ArrayListUnmanaged(DrawCommand){};
        defer commands.deinit(allocator);

        // Backgrounds
        var bg_it = world.background_store.iterator();
        while (bg_it.next()) |entry| {
            const e = entry.key_ptr.*;
            const z = if (world.z_index_store.get(e)) |zi| zi.value else 0;
            const bg = entry.value_ptr.*;
            try commands.append(allocator, .{ .z = z, .x = 0, .y = 0, .cmd = .{ .background = .{ .texture = bg.texture, .repeat = bg.repeat } } });
        }

        // Sprites
        var sp_it = world.sprite_store.iterator();
        while (sp_it.next()) |entry| {
            const e = entry.key_ptr.*;
            const tr_opt = world.transform_store.get(e);
            if (tr_opt) |tr| {
                const z = if (world.z_index_store.get(e)) |zi| zi.value else 0;
                const spr = entry.value_ptr.*;
                const src = spr.calcSourceRect();
                const tint = spriteTint(world, e);
                try commands.append(allocator, .{
                    .z = z,
                    .x = tr.x,
                    .y = tr.y,
                    .cmd = .{ .sprite = .{
                        .texture = spr.texture,
                        .src = src,
                        .w = @floatFromInt(spr.grid.frame_width),
                        .h = @floatFromInt(spr.grid.frame_height),
                        .color = tint,
                    } },
                });
            }
        }

        std.sort.block(DrawCommand, commands.items, {}, struct {
            fn lessThan(_: void, a: DrawCommand, b: DrawCommand) bool {
                return a.z < b.z;
            }
        }.lessThan);

        for (commands.items) |dc| {
            switch (dc.cmd) {
                .background => |bg| {
                    if (bg.repeat) {
                        // Get screen dimensions
                        const screen_width = raylib.cdef.GetScreenWidth();
                        const screen_height = raylib.cdef.GetScreenHeight();
                        const tex_width = @as(f32, @floatFromInt(bg.texture.width));
                        const tex_height = @as(f32, @floatFromInt(bg.texture.height));

                        // Calculate how many tiles we need
                        const tiles_x = @as(i32, @intFromFloat(@ceil(@as(f32, @floatFromInt(screen_width)) / tex_width)));
                        const tiles_y = @as(i32, @intFromFloat(@ceil(@as(f32, @floatFromInt(screen_height)) / tex_height)));

                        // Draw repeated tiles
                        var y: i32 = 0;
                        while (y < tiles_y) : (y += 1) {
                            var x: i32 = 0;
                            while (x < tiles_x) : (x += 1) {
                                raylib.cdef.DrawTexture(bg.texture, x * @as(i32, @intFromFloat(tex_width)), y * @as(i32, @intFromFloat(tex_height)), raylib.Color.white);
                            }
                        }
                    } else {
                        raylib.cdef.DrawTexture(bg.texture, 0, 0, raylib.Color.white);
                    }
                },
                .sprite => |s| {
                    const dest = raylib.Rectangle{ .x = dc.x, .y = dc.y, .width = s.w, .height = s.h };
                    const origin = raylib.Vector2{ .x = 0, .y = 0 };
                    raylib.cdef.DrawTexturePro(s.texture, s.src, dest, origin, 0, s.color);
                },
            }
        }
    }
};

fn spriteTint(world: *WorldMod.World, entity: WorldMod.Entity) raylib.Color {
    if (world.player_health_store.get(entity)) |health| {
        if (health.blink_is_red) {
            return raylib.Color{ .r = 255, .g = 120, .b = 120, .a = 255 };
        }
    }
    return raylib.Color.white;
}
