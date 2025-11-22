const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");

pub const AnimationSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        var it = world.sprite_store.iterator();
        while (it.next()) |entry| {
            var sprite = entry.value_ptr;
            sprite.frame_time += dt;
            const seconds_per_frame = sprite.seconds_per_frame;
            if (sprite.frame_time >= seconds_per_frame) {
                sprite.frame_time -= seconds_per_frame;
                const anim = sprite.getCurrentAnimation();
                const frames_len_i32: i32 = @intCast(anim.frames.len);
                sprite.frame_index = @rem(sprite.frame_index + 1, frames_len_i32);
            }
        }
    }

    pub fn syncDirectionAndState(world: *WorldMod.World, player_entity: WorldMod.Entity) void {
        // For now, infer direction from velocity, and set animation based on moving or not
        const sprite_opt = world.sprite_store.getPtr(player_entity);
        const vel_opt = world.velocity_store.get(player_entity);
        if (sprite_opt) |sprite| {
            var moving = false;
            var running = false;
            if (vel_opt) |v| {
                moving = (v.vx != 0 or v.vy != 0);
                running = moving and v.is_running;
                if (@abs(v.vx) >= @abs(v.vy)) {
                    sprite.direction = if (v.vx >= 0) .right else .left;
                } else {
                    sprite.direction = if (v.vy >= 0) .front else .back;
                }
            }
            if (moving) {
                sprite.current = if (running) .run else .walk;
            } else {
                sprite.current = .idle;
            }
        }
    }
};
