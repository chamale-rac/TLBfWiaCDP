const raylib = @import("raylib");
const WorldMod = @import("../World.zig");
const DebugRenderSystemMod = @import("DebugRenderSystem.zig");
const Assets = @import("../../assets/Assets.zig");
const AnimatedSprite = @import("../components/AnimatedSprite.zig");
const ProjectileComp = @import("../components/Projectile.zig");
const CollisionConfig = @import("../components/CollisionConfig.zig");

pub const InputSystem = struct {
    debug_system: *DebugRenderSystemMod.DebugRenderSystem,
    assets: *Assets.Assets,
    player_entity: WorldMod.Entity,
    throw_cooldown: f32 = 0.0,
    last_throw_dir: DirectionVector = DEFAULT_THROW_DIR,

    const DirectionVector = struct {
        x: f32,
        y: f32,
    };

    const DEFAULT_THROW_DIR = DirectionVector{ .x = 0.0, .y = 1.0 };
    const MOVE_SPEED: f32 = 100.0;
    const ROCK_SPEED: f32 = 460.0;
    const ROCK_LIFETIME: f32 = 2.0;
    const ROCK_COOLDOWN: f32 = 0.5;
    const THROW_OFFSET: f32 = 32.0;
    const ROCK_RENDER_SCALE: f32 = 0.35;

    const SINGLE_FRAME = [_]i32{1};
    const ROCK_ANIMATION_SET = AnimatedSprite.AnimationSet{
        .idle = .{ .start_row = 0, .frames = SINGLE_FRAME[0..] },
        .walk = .{ .start_row = 0, .frames = SINGLE_FRAME[0..] },
        .run = .{ .start_row = 0, .frames = SINGLE_FRAME[0..] },
    };

    pub fn init(
        debug_system: *DebugRenderSystemMod.DebugRenderSystem,
        assets: *Assets.Assets,
        player_entity: WorldMod.Entity,
    ) InputSystem {
        return .{
            .debug_system = debug_system,
            .assets = assets,
            .player_entity = player_entity,
        };
    }

    pub fn update(self: *@This(), world: *WorldMod.World, dt: f32) !void {
        self.updateCooldown(dt);

        if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.f1)) {
            self.debug_system.toggle();
        }

        if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.f2)) {
            self.debug_system.toggleSpawners();
        }

        self.handleMovement(world);
        try self.handleThrow(world);
    }

    fn updateCooldown(self: *@This(), dt: f32) void {
        if (self.throw_cooldown <= 0.0) return;
        self.throw_cooldown -= dt;
        if (self.throw_cooldown < 0.0) {
            self.throw_cooldown = 0.0;
        }
    }

    fn handleMovement(self: *@This(), world: *WorldMod.World) void {
        var it = world.velocity_store.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            if (!world.transform_store.contains(e)) continue;

            var v = entry.value_ptr;
            v.vx = 0;
            v.vy = 0;
            if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.w)) v.vy -= MOVE_SPEED;
            if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.s)) v.vy += MOVE_SPEED;
            if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.a)) v.vx -= MOVE_SPEED;
            if (raylib.cdef.IsKeyDown(raylib.KeyboardKey.d)) v.vx += MOVE_SPEED;

            if (e == self.player_entity) {
                self.updateLastDirection(v.vx, v.vy);
            }
        }
    }

    fn updateLastDirection(self: *@This(), vx: f32, vy: f32) void {
        const magnitude = @sqrt(vx * vx + vy * vy);
        if (magnitude <= 0.001) {
            return;
        }
        self.last_throw_dir = .{
            .x = vx / magnitude,
            .y = vy / magnitude,
        };
    }

    fn handleThrow(self: *@This(), world: *WorldMod.World) !void {
        if (!raylib.cdef.IsKeyDown(raylib.KeyboardKey.space)) return;
        if (self.throw_cooldown > 0.0) return;

        if (try self.spawnRock(world)) {
            self.throw_cooldown = ROCK_COOLDOWN;
        }
    }

    fn spawnRock(self: *@This(), world: *WorldMod.World) !bool {
        const player_transform = world.transform_store.get(self.player_entity) orelse return false;

        var dir = self.last_throw_dir;
        var magnitude = @sqrt(dir.x * dir.x + dir.y * dir.y);
        if (magnitude <= 0.001) {
            dir = DEFAULT_THROW_DIR;
            magnitude = 1.0;
        }

        const norm_dir = DirectionVector{
            .x = dir.x / magnitude,
            .y = dir.y / magnitude,
        };

        const rock_entity = world.create();
        const width = @as(f32, @floatFromInt(self.assets.rock.width));
        const height = @as(f32, @floatFromInt(self.assets.rock.height));
        const render_width = width * ROCK_RENDER_SCALE;
        const render_height = height * ROCK_RENDER_SCALE;
        const half_width = render_width / 2.0;
        const half_height = render_height / 2.0;
        const spawn_x = player_transform.x + CollisionConfig.CollisionConfig.SPRITE_HALF_WIDTH - half_width + norm_dir.x * THROW_OFFSET;
        const spawn_y = player_transform.y + CollisionConfig.CollisionConfig.SPRITE_HALF_HEIGHT - half_height + norm_dir.y * THROW_OFFSET;

        try world.transform_store.set(rock_entity, .{ .x = spawn_x, .y = spawn_y });
        try world.sprite_store.set(rock_entity, .{
            .texture = self.assets.rock,
            .grid = .{
                .image_width = @as(i32, @intCast(self.assets.rock.width)),
                .image_height = @as(i32, @intCast(self.assets.rock.height)),
                .frame_width = @as(i32, @intCast(self.assets.rock.width)),
                .frame_height = @as(i32, @intCast(self.assets.rock.height)),
            },
            .set = ROCK_ANIMATION_SET,
            .current = .idle,
            .direction = .front,
            .seconds_per_frame = 1.0,
            .layer = 1,
            .render_scale = ROCK_RENDER_SCALE,
        });
        try world.z_index_store.set(rock_entity, .{ .value = 1 });

        const max_dim = @max(render_width, render_height);
        try world.projectile_store.set(rock_entity, ProjectileComp.Projectile{
            .dir_x = norm_dir.x,
            .dir_y = norm_dir.y,
            .speed = ROCK_SPEED,
            .lifetime = ROCK_LIFETIME,
            .half_width = half_width,
            .half_height = half_height,
            .hit_radius = max_dim / 2.0,
            .damage = 1,
        });

        return true;
    }
};
