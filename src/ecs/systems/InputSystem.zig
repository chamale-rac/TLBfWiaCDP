const raylib = @import("raylib");
const WorldMod = @import("../World.zig");

pub const InputSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        _ = dt;
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (world.transform_store.contains(e)) {
                var v = entry.value_ptr;
                v.vx = 0;
                v.vy = 0;
                const speed: f32 = 100;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.key_w)) v.vy -= speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.key_s)) v.vy += speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.key_a)) v.vx -= speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.key_d)) v.vx += speed;
            }
        }
    }
};
