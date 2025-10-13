const std = @import("std");
const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const CameraComp = @import("../components/Camera2D.zig");

fn approach(current: f32, target: f32, max_delta: f32) f32 {
    if (current < target) {
        return if (target - current <= max_delta) target else current + max_delta;
    } else {
        return if (current - target <= max_delta) target else current - max_delta;
    }
}

pub const CameraSystem = struct {
    pub fn setupCenterOn(world: *WorldMod.World, camera_entity: WorldMod.Entity, target_entity: WorldMod.Entity, zoom: f32) !void {
        const screen_w: f32 = @floatFromInt(raylib.cdef.GetScreenWidth());
        const screen_h: f32 = @floatFromInt(raylib.cdef.GetScreenHeight());
        const half_w = screen_w * 0.5;
        const half_h = screen_h * 0.5;

        var cam: CameraComp.Camera2D = .{ .target_entity = target_entity, .zoom = zoom, .offset_x = half_w, .offset_y = half_h };
        if (world.transform_store.get(target_entity)) |tr| {
            cam.computed_target_x = tr.x;
            cam.computed_target_y = tr.y;
        }
        try world.camera_store.set(camera_entity, cam);
    }

    pub fn update(world: *WorldMod.World, dt: f32) void {
        var it = world.camera_store.iterator();
        while (it.next()) |entry| {
            var cam = entry.value_ptr;

            // Follow target if any
            if (cam.target_entity) |t| {
                if (world.transform_store.get(t)) |tr| {
                    if (cam.follow_lerp_speed <= 0) {
                        cam.computed_target_x = tr.x;
                        cam.computed_target_y = tr.y;
                    } else {
                        const max_delta = cam.follow_lerp_speed * dt;
                        cam.computed_target_x = approach(cam.computed_target_x, tr.x, max_delta);
                        cam.computed_target_y = approach(cam.computed_target_y, tr.y, max_delta);
                    }
                }
            }

            // Shake effect decay
            if (cam.shake_time_remaining > 0) {
                cam.shake_time_remaining -= dt;
                if (cam.shake_time_remaining < 0) cam.shake_time_remaining = 0;
            }
        }
    }

    pub fn begin2D(world: *WorldMod.World, camera_entity: WorldMod.Entity) void {
        if (world.camera_store.get(camera_entity)) |cam| {
            var rl_cam = raylib.Camera2D{
                .offset = .{ .x = cam.offset_x, .y = cam.offset_y },
                .target = .{ .x = cam.computed_target_x, .y = cam.computed_target_y },
                .rotation = cam.rotation_deg,
                .zoom = cam.zoom,
            };

            // Apply shake as small random offset around target
            if (cam.shake_time_remaining > 0 and cam.shake_intensity > 0) {
                const t: f32 = @floatCast(raylib.cdef.GetTime());
                const sx = std.math.sin(t * cam.shake_frequency) * cam.shake_intensity;
                const sy = std.math.cos(t * cam.shake_frequency * 1.3) * cam.shake_intensity;
                rl_cam.target.x += sx;
                rl_cam.target.y += sy;
            }

            raylib.cdef.BeginMode2D(rl_cam);
        }
    }

    pub fn end2D() void {
        raylib.cdef.EndMode2D();
    }
};
