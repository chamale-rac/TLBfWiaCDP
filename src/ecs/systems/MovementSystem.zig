const WorldMod = @import("../World.zig");

pub const MovementSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (world.transform_store.getPtr(e)) |tr| {
                const v = entry.value_ptr.*;
                tr.x += v.vx * dt;
                tr.y += v.vy * dt;
            }
        }
    }
};
