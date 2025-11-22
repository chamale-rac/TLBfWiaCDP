const std = @import("std");
const WorldMod = @import("../World.zig");
const ProjectileComp = @import("../components/Projectile.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");
const Transform2D = @import("../components/Transform2D.zig");

const Rect = struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

pub const ProjectileSystem = struct {
    pub fn update(world: *WorldMod.World, dt: f32) void {
        var to_destroy = std.ArrayListUnmanaged(WorldMod.Entity){};
        defer to_destroy.deinit(world.allocator);

        var proj_it = world.projectile_store.iterator();
        while (proj_it.next()) |entry| {
            const entity = entry.key_ptr.*;
            var projectile = entry.value_ptr;

            var should_remove = false;
            projectile.lifetime -= dt;
            if (projectile.lifetime <= 0.0) {
                should_remove = true;
            }

            if (!should_remove) {
                if (world.transform_store.getPtr(entity)) |transform| {
                    transform.x += projectile.dir_x * projectile.speed * dt;
                    transform.y += projectile.dir_y * projectile.speed * dt;

                    if (handleEnemyCollision(world, projectile, transform)) {
                        should_remove = true;
                    }
                } else {
                    should_remove = true;
                }
            }

            if (should_remove) {
                to_destroy.append(world.allocator, entity) catch {
                    destroyProjectile(world, entity);
                };
            }
        }

        for (to_destroy.items) |entity| {
            destroyProjectile(world, entity);
        }
    }
};

fn handleEnemyCollision(world: *WorldMod.World, projectile: *ProjectileComp.Projectile, transform: *Transform2D.Transform2D) bool {
    const center_x = transform.x + projectile.half_width;
    const center_y = transform.y + projectile.half_height;

    var enemy_it = world.enemy_store.iterator();
    while (enemy_it.next()) |entry| {
        const enemy_entity = entry.key_ptr.*;
        const enemy_transform = world.transform_store.get(enemy_entity) orelse continue;
        const enemy_rect = rectFromTransform(enemy_transform);

        if (circleRectOverlap(center_x, center_y, projectile.hit_radius, enemy_rect)) {
            killEnemy(world, enemy_entity);
            return true;
        }
    }

    return false;
}

fn rectFromTransform(transform: Transform2D.Transform2D) Rect {
    const cfg = CollisionConfig.CollisionConfig;
    return .{
        .left = transform.x + cfg.WEST_INSET,
        .right = transform.x + cfg.SPRITE_WIDTH - cfg.EAST_INSET,
        .top = transform.y + cfg.NORTH_INSET,
        .bottom = transform.y + cfg.SPRITE_HEIGHT - cfg.SOUTH_INSET,
    };
}

fn killEnemy(world: *WorldMod.World, enemy_entity: WorldMod.Entity) void {
    if (world.enemy_store.get(enemy_entity)) |enemy| {
        if (enemy.spawner_entity) |spawner_id| {
            if (world.spawner_store.getPtr(spawner_id)) |spawner| {
                if (spawner.active_enemies > 0) {
                    spawner.active_enemies -= 1;
                }
            }
        }
    }

    if (world.movement_pattern_store.getPtr(enemy_entity)) |pattern| {
        pattern.deinit(world.allocator);
    }
    world.movement_pattern_store.remove(enemy_entity);
    world.enemy_store.remove(enemy_entity);
    world.transform_store.remove(enemy_entity);
    world.sprite_store.remove(enemy_entity);
    world.z_index_store.remove(enemy_entity);
}

fn destroyProjectile(world: *WorldMod.World, entity: WorldMod.Entity) void {
    world.projectile_store.remove(entity);
    world.transform_store.remove(entity);
    world.sprite_store.remove(entity);
    world.z_index_store.remove(entity);
}

fn circleRectOverlap(center_x: f32, center_y: f32, radius: f32, rect: Rect) bool {
    const clamped_x = std.math.clamp(center_x, rect.left, rect.right);
    const clamped_y = std.math.clamp(center_y, rect.top, rect.bottom);
    const dx = center_x - clamped_x;
    const dy = center_y - clamped_y;
    return dx * dx + dy * dy <= radius * radius;
}

