const WorldMod = @import("../World.zig");
const Transform2D = @import("../components/Transform2D.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");
const PlayerHealthMod = @import("../../effects/PlayerHealth.zig");

const Rect = struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

pub const PlayerDamageSystem = struct {
    pub fn update(world: *WorldMod.World, player_entity: WorldMod.Entity, health: *PlayerHealthMod.PlayerHealth, dt: f32) void {
        health.update(dt);

        if (health.isDead() or health.isInvulnerable()) {
            return;
        }

        const player_transform = world.transform_store.get(player_entity) orelse return;
        const player_rect = collisionRect(player_transform);

        var enemy_it = world.enemy_store.iterator();
        while (enemy_it.next()) |entry| {
            const enemy_entity = entry.key_ptr.*;
            const enemy_transform = world.transform_store.get(enemy_entity) orelse continue;
            const enemy_rect = collisionRect(enemy_transform);

            if (rectsOverlap(player_rect, enemy_rect)) {
                if (health.applyDamage(1)) {
                    break;
                }
            }
        }
    }
};

fn collisionRect(transform: Transform2D.Transform2D) Rect {
    const cfg = CollisionConfig.CollisionConfig;
    return .{
        .left = transform.x + cfg.WEST_INSET,
        .right = transform.x + cfg.SPRITE_WIDTH - cfg.EAST_INSET,
        .top = transform.y + cfg.NORTH_INSET,
        .bottom = transform.y + cfg.SPRITE_HEIGHT - cfg.SOUTH_INSET,
    };
}

fn rectsOverlap(a: Rect, b: Rect) bool {
    return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top;
}

