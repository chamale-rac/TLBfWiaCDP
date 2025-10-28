const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const DebugRenderSystemMod = @import("DebugRenderSystem.zig");

pub const InputSystem = struct {
    debug_system: *DebugRenderSystemMod.DebugRenderSystem,

    pub fn init(debug_system: *DebugRenderSystemMod.DebugRenderSystem) InputSystem {
        return .{ .debug_system = debug_system };
    }

    pub fn update(self: *@This(), world: *WorldMod.World, dt: f32) void {
        _ = dt;

        // Handle debug toggle
        if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.f1)) {
            self.debug_system.toggle();
        }

        // Handle spawner zone toggle
        if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.f2)) {
            self.debug_system.toggleSpawners();
        }

        // Handle movement
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (world.transform_store.contains(e)) {
                var v = entry.value_ptr;
                v.vx = 0;
                v.vy = 0;
                const speed: f32 = 100;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.w)) v.vy -= speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.s)) v.vy += speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.a)) v.vx -= speed;
                if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.d)) v.vx += speed;
            }
        }
    }
};
