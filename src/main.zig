//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const raylib = @import("raylib");
const raygui = @import("raygui");
const std = @import("std");
const WorldMod = @import("ecs/World.zig");
const Assets = @import("assets/Assets.zig");
const LPC = @import("assets/LPC.zig");
const AnimatedSprite = @import("ecs/components/AnimatedSprite.zig");
const InputSystem = @import("ecs/systems/InputSystem.zig");
const MovementSystem = @import("ecs/systems/MovementSystem.zig");
const AnimationSystem = @import("ecs/systems/AnimationSystem.zig");
const RenderSystem = @import("ecs/systems/RenderSystem.zig");
const TilemapLoadSystem = @import("ecs/systems/TilemapLoadSystem.zig");
const AutoTilingSystem = @import("ecs/systems/AutoTilingSystem.zig");
const TilemapRenderSystem = @import("ecs/systems/TilemapRenderSystem.zig");
const IntGridSystem = @import("ecs/systems/IntGridSystem.zig");
const DebugRenderSystem = @import("ecs/systems/DebugRenderSystem.zig");
const CameraSystem = @import("ecs/systems/CameraSystem.zig");
const SpecialTilesGenerationSystem = @import("ecs/systems/SpecialTilesGenerationSystem.zig");
const SpecialTilesRenderSystem = @import("ecs/systems/SpecialTilesRenderSystem.zig");
const EnemySpawnSystem = @import("ecs/systems/EnemySpawnSystem.zig");
const MovementPatternSystem = @import("ecs/systems/MovementPatternSystem.zig");
const SpawnerConfigLoader = @import("ecs/systems/SpawnerConfigLoader.zig");
const PlayerHealth = @import("effects/PlayerHealth.zig");
const PlayerStamina = @import("effects/PlayerStamina.zig");
const PlayerDamageSystem = @import("ecs/systems/PlayerDamageSystem.zig");
const CollectibleSystem = @import("ecs/systems/CollectibleSystem.zig");
const ProjectileSystem = @import("ecs/systems/ProjectileSystem.zig");
const CollisionConfig = @import("ecs/components/CollisionConfig.zig");

const GamePhase = enum { splash, menu, how_to, playing, pause, lost, won };
const MenuAction = enum { none, play, how_to };
const EndScreenAction = enum { none, restart, menu };
const PauseAction = enum { none, resume_game, restart, menu };
const splash_duration: f32 = 2.8;

const GameSession = struct {
    allocator: std.mem.Allocator,
    assets: *Assets.Assets,
    debug_system: *DebugRenderSystem.DebugRenderSystem,
    world: WorldMod.World,
    player: WorldMod.Entity,
    cam_entity: WorldMod.Entity,
    player_health: PlayerHealth.PlayerHealth,
    player_stamina: PlayerStamina.PlayerStamina,
    bottle_progress: CollectibleSystem.CollectibleSystem.Progress,
    level_completed: bool,
    spawn_system: EnemySpawnSystem.EnemySpawnSystem,
    movement_pattern_system: MovementPatternSystem.MovementPatternSystem,
    input_system: InputSystem.InputSystem,
    game_timer_entity: WorldMod.Entity,

    pub fn init(
        allocator: std.mem.Allocator,
        assets: *Assets.Assets,
        debug_system: *DebugRenderSystem.DebugRenderSystem,
    ) !GameSession {
        var world = WorldMod.World.init(allocator);
        errdefer world.deinit();

        const player_health = PlayerHealth.PlayerHealth.init(3);
        const player_stamina = PlayerStamina.PlayerStamina.init(100.0, 35.0, 28.0, 0.6);
        var bottle_progress = CollectibleSystem.CollectibleSystem.Progress.init(0);
        const level_completed = false;

        const player = world.create();
        try world.transform_store.set(player, .{ .x = 400, .y = 300 });
        try world.velocity_store.set(player, .{ .vx = 0, .vy = 0 });
        try world.sprite_store.set(player, .{
            .texture = assets.lpc_player,
            .grid = LPC.lpcGrid(),
            .set = LPC.lpcAnimationSet(),
            .current = .idle,
            .direction = .front,
            .seconds_per_frame = 0.12,
            .layer = 0,
        });
        try world.z_index_store.set(player, .{ .value = 0 });

        const camp = world.create();
        try world.transform_store.set(camp, .{ .x = 300, .y = 320 });
        const camp_set = AnimatedSprite.AnimationSet{
            .idle = .{ .start_row = 1, .frames = &[_]i32{ 1, 1, 2, 2, 3, 3, 4, 4 } },
            .walk = .{ .start_row = 1, .frames = &[_]i32{ 1, 2, 3, 4 } },
            .run = .{ .start_row = 1, .frames = &[_]i32{ 1, 2, 3, 4 } },
        };
        try world.sprite_store.set(camp, .{
            .texture = assets.campfire,
            .grid = .{ .image_width = 128, .image_height = 64, .frame_width = 32, .frame_height = 32 },
            .set = camp_set,
            .current = .idle,
            .direction = .back,
            .seconds_per_frame = 0.15,
            .layer = -1,
        });
        try world.z_index_store.set(camp, .{ .value = -1 });

        const cam_e = world.create();
        try CameraSystem.CameraSystem.setupCenterOn(&world, cam_e, player, 1.0);
        if (world.camera_store.getPtr(cam_e)) |cam|
            cam.follow_lerp_speed = 100.0;

        try TilemapLoadSystem.TilemapLoadSystem.loadFromNoise(&world, assets);
        AutoTilingSystem.AutoTilingSystem.setup(&world);
        IntGridSystem.IntGridSystem.setupFromTilemap(&world);

        const run_seed: u64 = @intCast(std.time.timestamp());
        const bottle_seed: u64 = run_seed ^ 0xB0771E;
        const desired_bottles: u32 = 3;
        const spawned_bottles = CollectibleSystem.CollectibleSystem.spawnBottles(&world, assets, bottle_seed, desired_bottles) catch |err| blk: {
            std.debug.print("Failed to spawn bottles: {}\n", .{err});
            break :blk 0;
        };
        bottle_progress.total = spawned_bottles;

        const special_tiles_config = SpecialTilesGenerationSystem.SpecialTilesConfig{
            .seed = 67890,
            .slowdown_frequency = 0.04,
            .speedup_frequency = 0.09,
            .push_frequency = 0.02,
            .slowdown_max_join = 5,
            .speedup_max_join = 6,
            .push_max_join = 1,
            .min_distance = 3,
        };
        try SpecialTilesGenerationSystem.SpecialTilesGenerationSystem.generateFromTilemap(&world, special_tiles_config);

        const game_timer_entity = world.create();
        try world.game_timer_store.set(game_timer_entity, .{});

        const spawn_seed: u64 = run_seed ^ 0xF00DF00D;
        const spawn_system = EnemySpawnSystem.EnemySpawnSystem.init(spawn_seed);
        const movement_pattern_system = MovementPatternSystem.MovementPatternSystem.init(player);

        SpawnerConfigLoader.SpawnerConfigLoader.loadFromFile(&world, allocator, "assets/spawner_config.json", spawn_seed) catch |err| {
            std.debug.print("Warning: Could not load assets/spawner_config.json: {}\n", .{err});
            std.debug.print("Creating default spawners instead...\n", .{});
            try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .circular, 500, 400, 6.0, 12, 0.0);
            try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .random, 1000, 600, 4.0, 10, 15.0);
            try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .line_horizontal, 700, 300, 5.0, 8, 30.0);
        };

        return .{
            .allocator = allocator,
            .assets = assets,
            .debug_system = debug_system,
            .world = world,
            .player = player,
            .cam_entity = cam_e,
            .player_health = player_health,
            .player_stamina = player_stamina,
            .bottle_progress = bottle_progress,
            .level_completed = level_completed,
            .spawn_system = spawn_system,
            .movement_pattern_system = movement_pattern_system,
            .input_system = undefined,
            .game_timer_entity = game_timer_entity,
        };
    }

    pub fn setupInput(self: *GameSession) void {
        self.input_system = InputSystem.InputSystem.init(self.debug_system, self.assets, self.player, &self.player_stamina);
    }

    pub fn deinit(self: *GameSession) void {
        self.world.deinit();
    }

    pub fn update(self: *GameSession, dt: f32) !void {
        if (self.world.game_timer_store.getPtr(self.game_timer_entity)) |timer| {
            timer.update(dt);
        }

        try self.input_system.update(&self.world, dt);
        try self.spawn_system.update(&self.world, self.assets, dt);
        self.movement_pattern_system.update(&self.world, dt);
        MovementSystem.MovementSystem.update(&self.world, dt);
        ProjectileSystem.ProjectileSystem.update(&self.world, dt);
        PlayerDamageSystem.PlayerDamageSystem.update(&self.world, self.player, &self.player_health, dt);
        CollectibleSystem.CollectibleSystem.update(&self.world, self.player, &self.bottle_progress);
        if (!self.level_completed and self.bottle_progress.isComplete()) {
            self.level_completed = true;
        }
        AnimationSystem.AnimationSystem.syncDirectionAndState(&self.world, self.player);
        AnimationSystem.AnimationSystem.update(&self.world, dt);
        CameraSystem.CameraSystem.update(&self.world, dt);
    }
};

fn destroySession(slot: *?GameSession) void {
    if (slot.*) |*existing| {
        existing.deinit();
        slot.* = null;
    }
}

fn startSession(
    slot: *?GameSession,
    allocator: std.mem.Allocator,
    assets: *Assets.Assets,
    debug_system: *DebugRenderSystem.DebugRenderSystem,
) !void {
    destroySession(slot);
    const session_value = try GameSession.init(allocator, assets, debug_system);
    slot.* = session_value;
    if (slot.*) |*stored| {
        stored.setupInput();
    }
}

pub fn main() !void {
    raylib.cdef.InitWindow(960, 540, "TLBfWiaCDP - ECS 2D");
    defer raylib.cdef.CloseWindow();
    raylib.cdef.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var assets = Assets.Assets.load(allocator);
    defer assets.unload();

    var debug_system = DebugRenderSystem.DebugRenderSystem{};
    var session: ?GameSession = null;
    defer destroySession(&session);

    var phase: GamePhase = .splash;
    var splash_timer: f32 = 0.0;
    var last_time: f32 = @floatCast(raylib.cdef.GetTime());

    while (!raylib.cdef.WindowShouldClose()) {
        const now: f32 = @floatCast(raylib.cdef.GetTime());
        const dt: f32 = now - last_time;
        last_time = now;

        switch (phase) {
            .splash => {
                splash_timer += dt;
                if (splash_timer >= splash_duration or
                    raylib.cdef.IsKeyPressed(raylib.KeyboardKey.enter) or
                    raylib.cdef.IsKeyPressed(raylib.KeyboardKey.space) or
                    raylib.cdef.IsMouseButtonPressed(raylib.MouseButton.left))
                {
                    phase = .menu;
                }
            },
            .playing => {
                if (session) |*game| {
                    game.update(dt) catch |err| {
                        std.debug.print("Update error: {}\n", .{err});
                    };
                    if (game.player_health.isDead()) {
                        phase = .lost;
                    } else if (game.level_completed) {
                        phase = .won;
                    } else if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.p)) {
                        phase = .pause;
                    }
                } else {
                    phase = .menu;
                }
            },
            .pause => {
                if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.p)) {
                    phase = .playing;
                }
            },
            else => {},
        }

        const gameplay_phase = switch (phase) {
            .playing, .pause, .lost, .won => true,
            else => false,
        };
        const clear_color = if (gameplay_phase)
            raylib.Color.ray_white
        else
            raylib.Color{ .r = 245, .g = 206, .b = 143, .a = 255 };

        raylib.cdef.BeginDrawing();
        defer raylib.cdef.EndDrawing();
        raylib.cdef.ClearBackground(clear_color);

        if (gameplay_phase) {
            if (session) |*game| {
                drawGameplay(game, &debug_system);
            }
        }

        switch (phase) {
            .splash => drawSplashScreen(&assets, splash_timer / splash_duration),
            .menu => {
                const action = drawMenuScreen();
                switch (action) {
                    .play => {
                        startSession(&session, allocator, &assets, &debug_system) catch |err| {
                            std.debug.print("Could not start game: {}\n", .{err});
                            break;
                        };
                        phase = .playing;
                    },
                    .how_to => phase = .how_to,
                    else => {},
                }
            },
            .how_to => {
                if (drawHowToPlay()) {
                    phase = .menu;
                }
            },
            .lost => {
                const end_action = drawEndScreen(false);
                switch (end_action) {
                    .restart => {
                        startSession(&session, allocator, &assets, &debug_system) catch |err| {
                            std.debug.print("Could not restart game: {}\n", .{err});
                            break;
                        };
                        phase = .playing;
                    },
                    .menu => {
                        destroySession(&session);
                        phase = .menu;
                    },
                    else => {},
                }
            },
            .pause => {
                const pause_action = drawPauseScreen();
                switch (pause_action) {
                    .resume_game => phase = .playing,
                    .restart => {
                        startSession(&session, allocator, &assets, &debug_system) catch |err| {
                            std.debug.print("Could not restart game: {}\n", .{err});
                            break;
                        };
                        phase = .playing;
                    },
                    .menu => {
                        destroySession(&session);
                        phase = .menu;
                    },
                    else => {},
                }
            },
            .won => {
                const end_action = drawEndScreen(true);
                switch (end_action) {
                    .restart => {
                        startSession(&session, allocator, &assets, &debug_system) catch |err| {
                            std.debug.print("Could not restart game: {}\n", .{err});
                            break;
                        };
                        phase = .playing;
                    },
                    .menu => {
                        destroySession(&session);
                        phase = .menu;
                    },
                    else => {},
                }
            },
            .playing => {},
        }
    }
}

fn drawPlayerHearts(health: PlayerHealth.PlayerHealth, assets: *const Assets.Assets) void {
    const hearts = health.getHearts();
    const target_size: f32 = 28.0;
    const texture_height = @max(1.0, @as(f32, @floatFromInt(assets.heart_filled.height)));
    const scale = target_size / texture_height;
    const heart_spacing: i32 = @as(i32, @intFromFloat(target_size + 6.0));
    const total_width = @as(i32, @intCast(hearts.max)) * heart_spacing;
    const screen_width = raylib.cdef.GetScreenWidth();
    const start_x = screen_width - total_width - 20;
    const y = 60;

    var index: u8 = 0;
    while (index < hearts.max) : (index += 1) {
        const heart_x = start_x + @as(i32, index) * heart_spacing;
        const is_full = index < hearts.current;
        const texture = if (is_full) assets.heart_filled else assets.heart_empty;
        const draw_pos = raylib.Vector2{
            .x = @as(f32, @floatFromInt(heart_x)),
            .y = @as(f32, @floatFromInt(y)),
        };
        raylib.cdef.DrawTextureEx(texture, draw_pos, 0.0, scale, raylib.Color.white);
    }
}

fn drawBottleProgress(progress: CollectibleSystem.CollectibleSystem.Progress, assets: *const Assets.Assets) void {
    if (progress.total == 0) return;

    const label_x: i32 = 20;
    const text_y: i32 = 20;
    var label_buffer: [64]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&label_buffer, "Botellas: {d}/{d}", .{ progress.collected, progress.total }) catch "Botellas: ?";
    raylib.cdef.DrawText(label_text.ptr, label_x, text_y, 22, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });

    const target_size: f32 = 36.0;
    const texture_height = @max(1.0, @as(f32, @floatFromInt(assets.bottle.height)));
    const scale = target_size / texture_height;
    const spacing: i32 = @as(i32, @intFromFloat(target_size + 10.0));

    var index: u32 = 0;
    while (index < progress.total) : (index += 1) {
        const bottle_x = label_x + @as(i32, @intCast(index)) * spacing;
        const color = if (index < progress.collected)
            raylib.Color.white
        else
            raylib.Color{ .r = 255, .g = 255, .b = 255, .a = 120 };
        const draw_pos = raylib.Vector2{
            .x = @as(f32, @floatFromInt(bottle_x)),
            .y = @as(f32, @floatFromInt(text_y + 30)),
        };
        raylib.cdef.DrawTextureEx(assets.bottle, draw_pos, 0.0, scale, color);
    }
}

fn drawStaminaBar(stamina: PlayerStamina.PlayerStamina) void {
    const label_x: i32 = 20;
    const bar_width: i32 = 240;
    const bar_height: i32 = 16;
    const screen_height = raylib.cdef.GetScreenHeight();
    const bar_y = screen_height - bar_height - 30;
    const label_y = bar_y - 26;

    raylib.cdef.DrawText("Resistencia", label_x, label_y, 18, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });

    const outline_color = raylib.Color{ .r = 15, .g = 15, .b = 15, .a = 220 };
    const bg_color = raylib.Color{ .r = 40, .g = 40, .b = 40, .a = 200 };
    const fill_high = raylib.Color{ .r = 0, .g = 200, .b = 120, .a = 230 };
    const fill_low = raylib.Color{ .r = 230, .g = 120, .b = 0, .a = 230 };

    const ratio = std.math.clamp(stamina.fraction(), 0.0, 1.0);
    const inner_width = bar_width - 4;
    const fill_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(inner_width)) * ratio));
    const fill_color = if (ratio > 0.3) fill_high else fill_low;

    raylib.cdef.DrawRectangle(label_x - 2, bar_y - 2, bar_width + 4, bar_height + 4, outline_color);
    raylib.cdef.DrawRectangle(label_x, bar_y, bar_width, bar_height, bg_color);
    raylib.cdef.DrawRectangle(label_x + 2, bar_y + 2, fill_width, bar_height - 4, fill_color);

    var text_buffer: [32]u8 = undefined;
    const percent_value: i32 = @intFromFloat(ratio * 100.0);
    const text = std.fmt.bufPrintZ(&text_buffer, "{d}%", .{percent_value}) catch "??%";
    const text_x = label_x + bar_width + 12;
    raylib.cdef.DrawText(text.ptr, text_x, bar_y - 2, 18, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });
}

fn drawGameplay(session: *GameSession, debug_system: *DebugRenderSystem.DebugRenderSystem) void {
    CameraSystem.CameraSystem.begin2D(&session.world, session.cam_entity);
    TilemapRenderSystem.TilemapRenderSystem.draw(&session.world);
    SpecialTilesRenderSystem.SpecialTilesRenderSystem.draw(&session.world);
    const player_tint: ?RenderSystem.RenderSystem.TintOverride = blk: {
        if (session.player_health.isBlinking()) {
            const color = if (session.player_health.isBlinkPhaseRed())
                raylib.Color{ .r = 255, .g = 100, .b = 100, .a = 255 }
            else
                raylib.Color.white;
            break :blk .{ .entity = session.player, .color = color };
        }
        break :blk null;
    };
    RenderSystem.RenderSystem.draw(&session.world, player_tint) catch |err| {
        std.debug.print("Render error: {}\n", .{err});
    };
    debug_system.draw(&session.world);
    drawBottleIndicators(&session.world, session.player);
    CameraSystem.CameraSystem.end2D();

    if (session.world.game_timer_store.get(session.game_timer_entity)) |timer| {
        const minutes = timer.getMinutes();
        const seconds = timer.getSeconds();
        var timer_buffer: [64]u8 = undefined;
        const timer_text = std.fmt.bufPrintZ(&timer_buffer, "TIEMPO: {d:0>2}:{d:0>2}", .{ @abs(minutes), @abs(seconds) }) catch "TIME: ??:??";
        const screen_width = raylib.cdef.GetScreenWidth();
        const timer_x = screen_width - 200;
        const timer_y = 10;
        raylib.cdef.DrawRectangle(timer_x - 10, timer_y - 5, 180, 38, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 150 });
        raylib.cdef.DrawText(timer_text.ptr, timer_x, timer_y, 24, raylib.Color{ .r = 255, .g = 215, .b = 0, .a = 255 });
    }

    drawPlayerHearts(session.player_health, session.assets);
    drawBottleProgress(session.bottle_progress, session.assets);
    drawStaminaBar(session.player_stamina);

    // raylib.cdef.DrawText("F1 - Toggle Debug Overlay", 10, 10, 18, raylib.Color.black);
    // raylib.cdef.DrawText("F2 - Toggle Spawner Zones", 10, 30, 18, raylib.Color.black);
    if (debug_system.show_debug) {
        raylib.cdef.DrawText("Debug: ON (Green=Walkable, Red=No-Go)", 10, 50, 16, raylib.Color.red);
        raylib.cdef.DrawText("Player collision points shown as small circles", 10, 70, 14, raylib.Color.blue);
    }
}

fn drawBottleIndicators(world: *WorldMod.World, player_entity: WorldMod.Entity) void {
    const player_transform = world.transform_store.get(player_entity) orelse return;
    const cfg = CollisionConfig.CollisionConfig;
    const player_center = raylib.Vector2{
        .x = player_transform.x + cfg.SPRITE_HALF_WIDTH,
        .y = player_transform.y + cfg.SPRITE_HALF_HEIGHT,
    };

    var it = world.collectible_store.iterator();
    while (it.next()) |entry| {
        const entity = entry.key_ptr.*;
        const collectible = entry.value_ptr.*;
        if (collectible.kind != .bottle) continue;
        const transform = world.transform_store.get(entity) orelse continue;

        const bottle_center = raylib.Vector2{
            .x = transform.x + collectible.width / 2.0,
            .y = transform.y + collectible.height / 2.0,
        };

        const dx = bottle_center.x - player_center.x;
        const dy = bottle_center.y - player_center.y;
        const dist_sq = dx * dx + dy * dy;
        if (dist_sq <= 0.0001) continue;

        const inv_dist = 1.0 / @sqrt(dist_sq);
        const dir_x = dx * inv_dist;
        const dir_y = dy * inv_dist;

        const base_radius: f32 = 52.0;
        const arrow_length: f32 = 22.0;
        const half_width: f32 = 7.0;

        const base = raylib.Vector2{
            .x = player_center.x + dir_x * base_radius,
            .y = player_center.y + dir_y * base_radius,
        };
        const tip = raylib.Vector2{
            .x = base.x + dir_x * arrow_length,
            .y = base.y + dir_y * arrow_length,
        };

        const perp_x = -dir_y;
        const perp_y = dir_x;
        const left = raylib.Vector2{
            .x = base.x - perp_x * half_width,
            .y = base.y - perp_y * half_width,
        };
        const right = raylib.Vector2{
            .x = base.x + perp_x * half_width,
            .y = base.y + perp_y * half_width,
        };

        const color = raylib.Color{ .r = 255, .g = 140, .b = 0, .a = 215 };
        raylib.cdef.DrawTriangle(tip, left, right, color);
    }
}

fn drawSplashScreen(assets: *Assets.Assets, ratio: f32) void {
    const screen_w = raylib.cdef.GetScreenWidth();
    const screen_h = raylib.cdef.GetScreenHeight();
    const banner = assets.banner;
    const source = raylib.Rectangle{
        .x = 0,
        .y = 0,
        .width = @as(f32, @floatFromInt(banner.width)),
        .height = @as(f32, @floatFromInt(banner.height)),
    };
    const dest = raylib.Rectangle{
        .x = 0,
        .y = 0,
        .width = @as(f32, @floatFromInt(screen_w)),
        .height = @as(f32, @floatFromInt(screen_h)),
    };
    const origin = raylib.Vector2{ .x = 0, .y = 0 };
    raylib.cdef.DrawTexturePro(banner, source, dest, origin, 0.0, raylib.Color.white);

    // drawCenteredText("The Last Bottle of Water", 40, 34, raylib.Color{ .r = 255, .g = 255, .b = 255, .a = 230 });
    // drawCenteredText("in a completely dry desert", 80, 20, raylib.Color{ .r = 250, .g = 214, .b = 165, .a = 230 });

    const clamped = std.math.clamp(ratio, 0.0, 1.0);
    var buffer: [64]u8 = undefined;
    const hint = std.fmt.bufPrintZ(&buffer, "Press Enter or Click to continue", .{}) catch "Press...";
    const font_size = 20;
    const width = raylib.cdef.MeasureText(hint.ptr, font_size);
    const x = @divTrunc(screen_w - width, 2);
    const y = screen_h - 50;
    const alpha = @as(u8, @intCast(60 + @as(i32, @intFromFloat(clamped * 180.0))));
    raylib.cdef.DrawRectangle(x - 20, y - 10, width + 40, font_size + 20, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });
    raylib.cdef.DrawText(hint.ptr, x, y, font_size, raylib.Color{ .r = 255, .g = 255, .b = 255, .a = alpha });
}

fn drawMenuScreen() MenuAction {
    drawCenteredText("TLBfWiaCDP", 60, 48, raylib.Color{ .r = 110, .g = 60, .b = 30, .a = 255 });
    drawCenteredText("The Last Bottle of Water", 110, 22, raylib.Color{ .r = 90, .g = 50, .b = 20, .a = 255 });
    drawCenteredText("Survive the desert, recover every drop.", 145, 18, raylib.Color{ .r = 120, .g = 70, .b = 32, .a = 255 });

    const screen_w = @as(f32, @floatFromInt(raylib.cdef.GetScreenWidth()));
    const button_w: f32 = 260;
    const button_h: f32 = 60;
    const start_y: f32 = 220;
    const center_x = screen_w / 2.0 - button_w / 2.0;

    const play_rect = raylib.Rectangle{ .x = center_x, .y = start_y, .width = button_w, .height = button_h };
    const how_rect = raylib.Rectangle{ .x = center_x, .y = start_y + 80, .width = button_w, .height = button_h };

    if (drawButton(play_rect, "Play", true)) return .play;
    if (drawButton(how_rect, "How to Play", false)) return .how_to;

    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.enter)) return .play;
    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.h)) return .how_to;

    return .none;
}

fn drawHowToPlay() bool {
    drawCenteredText("How to play", 40, 40, raylib.Color{ .r = 80, .g = 40, .b = 20, .a = 255 });
    const details = [_][]const u8{
        "Objective: collect every water bottle before the desert critters get you.",
        "Movement: W, A, S, D",
        "Sprint: Hold Shift to run faster (consumes stamina).",
        "Defense: Press Space to throw a rock in the last direction you moved.",
        "Survival: You only have 3 hits, so dodge or stun enemies quickly.",
        "Tip: Rocks can push enemies back—use them to carve a safe path.",
        "Pause: Press P to open the pause menu (resume, restart or go back).",
    };
    var y: i32 = 110;
    for (details) |line| {
        var buffer: [200]u8 = undefined;
        const cz = std.fmt.bufPrintZ(&buffer, "{s}", .{line}) catch continue;
        raylib.cdef.DrawText(cz.ptr, 80, y, 20, raylib.Color{ .r = 30, .g = 15, .b = 5, .a = 255 });
        y += 32;
    }

    const screen_w = @as(f32, @floatFromInt(raylib.cdef.GetScreenWidth()));
    const button_rect = raylib.Rectangle{
        .x = screen_w / 2.0 - 150.0,
        .y = 420,
        .width = 300,
        .height = 55,
    };

    if (drawButton(button_rect, "Back to menu", true)) return true;
    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.escape)) return true;

    return false;
}

fn drawEndScreen(did_win: bool) EndScreenAction {
    const screen_w = raylib.cdef.GetScreenWidth();
    const screen_h = raylib.cdef.GetScreenHeight();
    raylib.cdef.DrawRectangle(0, 0, screen_w, screen_h, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 160 });

    const card = raylib.Rectangle{
        .x = 130,
        .y = 130,
        .width = @as(f32, @floatFromInt(screen_w - 260)),
        .height = 260,
    };
    raylib.cdef.DrawRectangleRec(card, raylib.Color{ .r = 254, .g = 230, .b = 189, .a = 240 });
    raylib.cdef.DrawRectangleLinesEx(card, 3.0, raylib.Color{ .r = 120, .g = 70, .b = 32, .a = 255 });

    if (did_win) {
        drawCenteredTextInRect(card, "You saved the last bottle!", 36, raylib.Color{ .r = 60, .g = 120, .b = 60, .a = 255 });
        drawCenteredText("All bottles recovered. The caravan lives!", 220, 20, raylib.Color{ .r = 40, .g = 80, .b = 40, .a = 255 });
    } else {
        drawCenteredTextInRect(card, "You lost the last bottle...", 36, raylib.Color{ .r = 160, .g = 40, .b = 30, .a = 255 });
        drawCenteredText("The desert beasts got you. Try again!", 220, 20, raylib.Color{ .r = 100, .g = 30, .b = 20, .a = 255 });
    }

    const button_w: f32 = 200;
    const button_h: f32 = 55;
    const spacing: f32 = 30;
    const total_width = button_w * 2.0 + spacing;
    const start_x = @as(f32, @floatFromInt(screen_w)) / 2.0 - total_width / 2.0;
    const y = card.y + card.height - button_h - 30.0;

    const restart_rect = raylib.Rectangle{ .x = start_x, .y = y, .width = button_w, .height = button_h };
    const menu_rect = raylib.Rectangle{ .x = start_x + button_w + spacing, .y = y, .width = button_w, .height = button_h };

    if (drawButton(restart_rect, "Restart", true)) return .restart;
    if (drawButton(menu_rect, "Main menu", false)) return .menu;
    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.enter)) return .restart;
    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.escape)) return .menu;

    return .none;
}

fn drawPauseScreen() PauseAction {
    const screen_w = raylib.cdef.GetScreenWidth();
    const screen_h = raylib.cdef.GetScreenHeight();
    raylib.cdef.DrawRectangle(0, 0, screen_w, screen_h, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });

    const card = raylib.Rectangle{
        .x = 160,
        .y = 140,
        .width = @as(f32, @floatFromInt(screen_w - 320)),
        .height = 230,
    };
    raylib.cdef.DrawRectangleRec(card, raylib.Color{ .r = 252, .g = 242, .b = 214, .a = 245 });
    raylib.cdef.DrawRectangleLinesEx(card, 2.0, raylib.Color{ .r = 110, .g = 70, .b = 32, .a = 255 });

    drawCenteredText("Juego en pausa", @as(i32, @intFromFloat(card.y + 35)), 34, raylib.Color{ .r = 90, .g = 60, .b = 35, .a = 255 });
    drawCenteredText("Presiona P para continuar en cualquier momento", @as(i32, @intFromFloat(card.y + 80)), 20, raylib.Color{ .r = 70, .g = 40, .b = 20, .a = 255 });

    const button_w: f32 = 200;
    const button_h: f32 = 52;
    const spacing: f32 = 24;
    const total_width = button_w * 3.0 + spacing * 2.0;
    const start_x = @as(f32, @floatFromInt(screen_w)) / 2.0 - total_width / 2.0;
    const y = card.y + card.height - button_h - 35.0;

    const resume_rect = raylib.Rectangle{ .x = start_x, .y = y, .width = button_w, .height = button_h };
    const restart_rect = raylib.Rectangle{ .x = start_x + button_w + spacing, .y = y, .width = button_w, .height = button_h };
    const menu_rect = raylib.Rectangle{ .x = start_x + (button_w + spacing) * 2.0, .y = y, .width = button_w, .height = button_h };

    if (drawButton(resume_rect, "Resume", true)) return .resume_game;
    if (drawButton(restart_rect, "Restart", false)) return .restart;
    if (drawButton(menu_rect, "Main menu", false)) return .menu;

    if (raylib.cdef.IsKeyPressed(raylib.KeyboardKey.escape)) return .menu;

    return .none;
}

fn drawButton(rect: raylib.Rectangle, label: []const u8, primary: bool) bool {
    const mouse = raylib.cdef.GetMousePosition();
    const hovered = pointInRect(mouse, rect);
    const clicked = hovered and raylib.cdef.IsMouseButtonPressed(raylib.MouseButton.left);

    const base = if (primary) raylib.Color{ .r = 189, .g = 93, .b = 38, .a = 255 } else raylib.Color{ .r = 90, .g = 50, .b = 30, .a = 255 };
    const hover = if (primary) raylib.Color{ .r = 214, .g = 120, .b = 60, .a = 255 } else raylib.Color{ .r = 112, .g = 72, .b = 45, .a = 255 };
    const draw_color = if (hovered) hover else base;
    raylib.cdef.DrawRectangleRec(rect, draw_color);
    raylib.cdef.DrawRectangleLinesEx(rect, 2.0, raylib.Color{ .r = 20, .g = 10, .b = 5, .a = 255 });

    drawCenteredTextInRect(rect, label, 26, raylib.Color.white);
    return clicked;
}

fn pointInRect(point: raylib.Vector2, rect: raylib.Rectangle) bool {
    return point.x >= rect.x and point.x <= rect.x + rect.width and point.y >= rect.y and point.y <= rect.y + rect.height;
}

fn drawCenteredText(text: []const u8, y: i32, font_size: i32, color: raylib.Color) void {
    var buffer: [160]u8 = undefined;
    const c_text = std.fmt.bufPrintZ(&buffer, "{s}", .{text}) catch return;
    const width = raylib.cdef.MeasureText(c_text.ptr, font_size);
    const screen_w = raylib.cdef.GetScreenWidth();
    const x = @divTrunc(screen_w - width, 2);
    raylib.cdef.DrawText(c_text.ptr, x, y, font_size, color);
}

fn drawCenteredTextInRect(rect: raylib.Rectangle, text: []const u8, font_size: i32, color: raylib.Color) void {
    var buffer: [160]u8 = undefined;
    const c_text = std.fmt.bufPrintZ(&buffer, "{s}", .{text}) catch return;
    const width = raylib.cdef.MeasureText(c_text.ptr, font_size);
    const x = @as(i32, @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(width))) / 2.0));
    const y = @as(i32, @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0));
    raylib.cdef.DrawText(c_text.ptr, x, y, font_size, color);
}
