const WorldMod = @import("../World.zig");
const Transform2D = @import("../components/Transform2D.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const PlayerHealthSystem = struct {
    player_entity: WorldMod.Entity,

    pub fn init(player_entity: WorldMod.Entity) PlayerHealthSystem {
        return .{ .player_entity = player_entity };
    }

    pub fn update(self: *PlayerHealthSystem, world: *WorldMod.World, dt: f32) void {
        const health = world.player_health_store.getPtr(self.player_entity) orelse return;
        health.updateTimers(dt);

        const player_transform = world.transform_store.get(self.player_entity) orelse return;

        if (health.isInvulnerable()) return;

        const player_bounds = boundsFromTransform(player_transform);

        var enemy_it = world.enemy_store.iterator();
        while (enemy_it.next()) |entry| {
            const enemy_entity = entry.key_ptr.*;
            const enemy_transform = world.transform_store.get(enemy_entity) orelse continue;
            const enemy_bounds = boundsFromTransform(enemy_transform);

            if (boundsOverlap(player_bounds, enemy_bounds)) {
                if (health.takeDamage(1)) {
                    break;
                }
            }
        }
    }
};

const Bounds = struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

fn boundsFromTransform(transform: Transform2D.Transform2D) Bounds {
    const cfg = CollisionConfig.CollisionConfig;
    return .{
        .left = transform.x + cfg.WEST_INSET,
        .right = transform.x + cfg.SPRITE_WIDTH - cfg.EAST_INSET,
        .top = transform.y + cfg.NORTH_INSET,
        .bottom = transform.y + cfg.SPRITE_HEIGHT - cfg.SOUTH_INSET,
    };
}

fn boundsOverlap(a: Bounds, b: Bounds) bool {
    const separated = a.right < b.left or a.left > b.right or a.bottom < b.top or a.top > b.bottom;
    return !separated;
}
