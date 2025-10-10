const std = @import("std");
const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");

const DrawCommand = struct {
    z: i32,
    x: f32,
    y: f32,
    cmd: union(enum) {
        background: raylib.Texture2D,
        sprite: struct {
            texture: raylib.Texture2D,
            src: raylib.Rectangle,
            w: f32,
            h: f32,
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
            try commands.append(allocator, .{ .z = z, .x = 0, .y = 0, .cmd = .{ .background = entry.value_ptr.texture } });
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
                try commands.append(allocator, .{
                    .z = z,
                    .x = tr.x,
                    .y = tr.y,
                    .cmd = .{ .sprite = .{
                        .texture = spr.texture,
                        .src = src,
                        .w = @floatFromInt(spr.grid.frame_width),
                        .h = @floatFromInt(spr.grid.frame_height),
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
                .background => |tex| {
                    raylib.cdef.DrawTexture(tex, 0, 0, raylib.Color.white);
                },
                .sprite => |s| {
                    const dest = raylib.Rectangle{ .x = dc.x, .y = dc.y, .width = s.w, .height = s.h };
                    const origin = raylib.Vector2{ .x = 0, .y = 0 };
                    raylib.cdef.DrawTexturePro(s.texture, s.src, dest, origin, 0, raylib.Color.white);
                },
            }
        }
    }
};
