//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const raylib = @import("raylib");
const raygui = @import("raygui");
const std = @import("std");
const WorldMod = @import("ecs/World.zig");
const Assets = @import("assets/Assets.zig");
const LPC = @import("assets/LPC.zig");
const Transform2D = @import("ecs/components/Transform2D.zig");
const Velocity2D = @import("ecs/components/Velocity2D.zig");
const AnimatedSprite = @import("ecs/components/AnimatedSprite.zig");
const Background = @import("ecs/components/Background.zig");
const ZIndex = @import("ecs/components/ZIndex.zig");
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
const CameraComp = @import("ecs/components/Camera2D.zig");
const SpecialTilesGenerationSystem = @import("ecs/systems/SpecialTilesGenerationSystem.zig");
const SpecialTilesRenderSystem = @import("ecs/systems/SpecialTilesRenderSystem.zig");
const EnemySpawnSystem = @import("ecs/systems/EnemySpawnSystem.zig");
const MovementPatternSystem = @import("ecs/systems/MovementPatternSystem.zig");
const SpawnerConfigLoader = @import("ecs/systems/SpawnerConfigLoader.zig");
const GameTimer = @import("ecs/components/GameTimer.zig");
const PlayerHealth = @import("effects/PlayerHealth.zig");
const PlayerStamina = @import("effects/PlayerStamina.zig");
const PlayerDamageSystem = @import("ecs/systems/PlayerDamageSystem.zig");
const CollectibleSystem = @import("ecs/systems/CollectibleSystem.zig");
const ProjectileSystem = @import("ecs/systems/ProjectileSystem.zig");
const CollisionConfig = @import("ecs/components/CollisionConfig.zig");

pub fn main() !void {
    // Initialize raylib
    raylib.cdef.InitWindow(960, 540, "TLBfWiaCDP - ECS 2D");
    defer raylib.cdef.CloseWindow();

    raylib.cdef.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load assets (requires window created)
    var assets = Assets.Assets.load(allocator);
    defer assets.unload();

    // World
    var world = WorldMod.World.init(allocator);
    defer world.deinit();

    // Background entity
    // const bg = world.create();
    // try world.background_store.set(bg, .{ .texture = assets.bg_desert, .repeat = true });
    // try world.z_index_store.set(bg, .{ .value = -1000 });

    // Player entity
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

    var player_health = PlayerHealth.PlayerHealth.init(3);
    var player_stamina = PlayerStamina.PlayerStamina.init(100.0, 35.0, 28.0, 0.6);
    var bottle_progress = CollectibleSystem.CollectibleSystem.Progress.init(0);
    var level_completed = false;
    const run_seed: u64 = @intCast(std.time.timestamp());
    const bottle_seed: u64 = run_seed ^ 0xB0771E;

    // Campfire entity (single row, 128x64 image, each frame 32x32, row index 1)
    const camp = world.create();
    try world.transform_store.set(camp, .{ .x = 300, .y = 320 });
    // Define a simple single-direction animation using AnimatedSprite
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

    // Camera entity: follow player
    const cam_e = world.create();
    // Initialize camera centered on player with screen center offset and default zoom 1
    try CameraSystem.CameraSystem.setupCenterOn(&world, cam_e, player, 1.0);
    if (world.camera_store.getPtr(cam_e)) |cam|
        cam.follow_lerp_speed = 100.0; // smooth following

    // Tilemap: noise-based generation and autotile once
    try TilemapLoadSystem.TilemapLoadSystem.loadFromNoise(&world, &assets);
    AutoTilingSystem.AutoTilingSystem.setup(&world);

    // Initialize IntGrid system for walkability
    IntGridSystem.IntGridSystem.setupFromTilemap(&world);

    const desired_bottles: u32 = 3;
    const spawned_bottles = CollectibleSystem.CollectibleSystem.spawnBottles(&world, &assets, bottle_seed, desired_bottles) catch |err| blk: {
        std.debug.print("Failed to spawn bottles: {}\n", .{err});
        break :blk 0;
    };
    bottle_progress.total = spawned_bottles;

    // Initialize special tiles with configurable parameters
    const special_tiles_config = SpecialTilesGenerationSystem.SpecialTilesConfig{
        .seed = 67890, // Random seed for tile generation
        .slowdown_frequency = 0.04, // 3% chance to start a slowdown sequence
        .speedup_frequency = 0.09, // 3% chance to start a speedup sequence
        .push_frequency = 0.02, // 1% chance to start a push tile
        .slowdown_max_join = 5, // Random length 1-5 tiles, random walk direction at each step
        .speedup_max_join = 6, // Random length 1-5 tiles, random walk direction at each step
        .push_max_join = 1, // Only 1 push tile (no consecutive)
        .min_distance = 3, // Each tile must be 3+ tiles away from all other tiles of same type
    };
    try SpecialTilesGenerationSystem.SpecialTilesGenerationSystem.generateFromTilemap(&world, special_tiles_config);

    // Create game timer entity
    const game_timer_entity = world.create();
    try world.game_timer_store.set(game_timer_entity, .{});

    // Initialize enemy spawning and movement systems
    const spawn_seed: u64 = run_seed ^ 0xF00DF00D;
    var spawn_system = EnemySpawnSystem.EnemySpawnSystem.init(spawn_seed);
    var movement_pattern_system = MovementPatternSystem.MovementPatternSystem.init(player);

    // Load spawner configuration from JSON
    SpawnerConfigLoader.SpawnerConfigLoader.loadFromFile(&world, allocator, "assets/spawner_config.json", spawn_seed) catch |err| {
        std.debug.print("Warning: Could not load assets/spawner_config.json: {}\n", .{err});
        std.debug.print("Creating default spawners instead...\n", .{});

        // Create some default spawners if config file fails
        try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .circular, 500, 400, 6.0, 12, 0.0);
        try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .random, 1000, 600, 4.0, 10, 15.0);
        try SpawnerConfigLoader.SpawnerConfigLoader.createDefaultSpawner(&world, .line_horizontal, 700, 300, 5.0, 8, 30.0);
    };

    // Initialize debug render system
    var debug_system = DebugRenderSystem.DebugRenderSystem{};
    var input_system = InputSystem.InputSystem.init(&debug_system, &assets, player, &player_stamina);

    var last_time: f32 = @floatCast(raylib.cdef.GetTime());

    while (!raylib.cdef.WindowShouldClose()) {
        const now: f32 = @floatCast(raylib.cdef.GetTime());
        const dt: f32 = now - last_time;
        last_time = now;

        // Update game timer
        if (world.game_timer_store.getPtr(game_timer_entity)) |timer| {
            timer.update(dt);
        }

        // Update systems
        try input_system.update(&world, dt);

        // Enemy systems
        try spawn_system.update(&world, &assets, dt);
        // Movement pattern system handles enemy movement and sprite direction
        movement_pattern_system.update(&world, dt);

        MovementSystem.MovementSystem.update(&world, dt);
        ProjectileSystem.ProjectileSystem.update(&world, dt);
        PlayerDamageSystem.PlayerDamageSystem.update(&world, player, &player_health, dt);
        CollectibleSystem.CollectibleSystem.update(&world, player, &bottle_progress);
        if (!level_completed and bottle_progress.isComplete()) {
            level_completed = true;
        }
        AnimationSystem.AnimationSystem.syncDirectionAndState(&world, player);
        AnimationSystem.AnimationSystem.update(&world, dt);
        // Update camera effects/follow
        CameraSystem.CameraSystem.update(&world, dt);

        // Draw
        raylib.cdef.BeginDrawing();
        defer raylib.cdef.EndDrawing();
        raylib.cdef.ClearBackground(raylib.Color.ray_white);

        // === 2D WORLD RENDERING (with camera) ===
        CameraSystem.CameraSystem.begin2D(&world, cam_e);
        // Draw tilemap first (water then grass per cell)
        TilemapRenderSystem.TilemapRenderSystem.draw(&world);
        // Draw special tiles (always visible)
        SpecialTilesRenderSystem.SpecialTilesRenderSystem.draw(&world);
        const player_tint: ?RenderSystem.RenderSystem.TintOverride = blk: {
            if (player_health.isBlinking()) {
                const color = if (player_health.isBlinkPhaseRed())
                    raylib.Color{ .r = 255, .g = 100, .b = 100, .a = 255 }
                else
                    raylib.Color.white;
                break :blk .{ .entity = player, .color = color };
            }
            break :blk null;
        };
        try RenderSystem.RenderSystem.draw(&world, player_tint);
        // Draw debug overlay if enabled (world-space elements)
        debug_system.draw(&world);
        drawBottleIndicators(&world, player);
        CameraSystem.CameraSystem.end2D();

        // === UI OVERLAY RENDERING (screen-space, fixed) ===
        // Draw survival timer (large and prominent)
        if (world.game_timer_store.get(game_timer_entity)) |timer| {
            const minutes = timer.getMinutes();
            const seconds = timer.getSeconds();
            var timer_buffer: [64]u8 = undefined;
            const timer_text = std.fmt.bufPrintZ(&timer_buffer, "TIEMPO: {d:0>2}:{d:0>2}", .{ @abs(minutes), @abs(seconds) }) catch "TIME: ??:??";

            // Draw with background for visibility
            const timer_x = 960 - 250;
            const timer_y = 10;
            raylib.cdef.DrawRectangle(timer_x - 10, timer_y - 5, 240, 45, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 150 });
            raylib.cdef.DrawText(timer_text.ptr, timer_x, timer_y, 32, raylib.Color{ .r = 255, .g = 215, .b = 0, .a = 255 }); // Gold
        }
        drawPlayerHearts(player_health, &assets);
        drawBottleProgress(bottle_progress, &assets);
        drawStaminaBar(player_stamina);

        // Draw UI text
        raylib.cdef.DrawText("F1 - Toggle Debug Overlay", 10, 10, 18, raylib.Color.black);
        raylib.cdef.DrawText("F2 - Toggle Spawner Zones", 10, 30, 18, raylib.Color.black);
        raylib.cdef.DrawText("Space - Throw Rock", 10, 50, 18, raylib.Color.dark_gray);
        if (debug_system.show_debug) {
            raylib.cdef.DrawText("Debug: ON (Green=Walkable, Red=Non-walkable)", 10, 70, 16, raylib.Color.red);
            raylib.cdef.DrawText("Player collision points shown as small circles", 10, 90, 14, raylib.Color.blue);
        }
        // Draw spawner stats
        var total_enemies: u32 = 0;
        var active_spawners: u32 = 0;
        var spawner_it = world.spawner_store.iterator();
        while (spawner_it.next()) |entry| {
            const spawner = entry.value_ptr.*;
            total_enemies += spawner.active_enemies;
            if (spawner.is_active_by_time) active_spawners += 1;
        }
        var enemy_buffer: [64]u8 = undefined;
        const enemy_text = std.fmt.bufPrintZ(&enemy_buffer, "Enemigos: {d}", .{total_enemies}) catch "Enemigos: ?";
        raylib.cdef.DrawText(enemy_text.ptr, 10, 130, 22, raylib.Color.dark_green);

        var spawner_buffer: [64]u8 = undefined;
        const spawner_text = std.fmt.bufPrintZ(&spawner_buffer, "Spawners Activos: {d}", .{active_spawners}) catch "Spawners: ?";
        raylib.cdef.DrawText(spawner_text.ptr, 10, 155, 18, raylib.Color.dark_blue);

        if (level_completed) {
            drawWinMessage();
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
    const label_y: i32 = 110;
    var label_buffer: [64]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&label_buffer, "Botellas: {d}/{d}", .{ progress.collected, progress.total }) catch "Botellas: ?";
    raylib.cdef.DrawText(label_text.ptr, label_x, label_y - 30, 20, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });

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
            .y = @as(f32, @floatFromInt(label_y)),
        };
        raylib.cdef.DrawTextureEx(assets.bottle, draw_pos, 0.0, scale, color);
    }
}

fn drawStaminaBar(stamina: PlayerStamina.PlayerStamina) void {
    const label_x: i32 = 20;
    const label_y: i32 = 150;
    const bar_width: i32 = 240;
    const bar_height: i32 = 16;

    raylib.cdef.DrawText("Resistencia", label_x, label_y - 22, 18, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });

    const outline_color = raylib.Color{ .r = 15, .g = 15, .b = 15, .a = 220 };
    const bg_color = raylib.Color{ .r = 40, .g = 40, .b = 40, .a = 200 };
    const fill_high = raylib.Color{ .r = 0, .g = 200, .b = 120, .a = 230 };
    const fill_low = raylib.Color{ .r = 230, .g = 120, .b = 0, .a = 230 };

    const ratio = std.math.clamp(stamina.fraction(), 0.0, 1.0);
    const inner_width = bar_width - 4;
    const fill_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(inner_width)) * ratio));
    const fill_color = if (ratio > 0.3) fill_high else fill_low;

    raylib.cdef.DrawRectangle(label_x - 2, label_y - 2, bar_width + 4, bar_height + 4, outline_color);
    raylib.cdef.DrawRectangle(label_x, label_y, bar_width, bar_height, bg_color);
    raylib.cdef.DrawRectangle(label_x + 2, label_y + 2, fill_width, bar_height - 4, fill_color);

    var text_buffer: [32]u8 = undefined;
    const percent_value: i32 = @intFromFloat(ratio * 100.0);
    const text = std.fmt.bufPrintZ(&text_buffer, "{d}%", .{percent_value}) catch "??%";
    const text_x = label_x + bar_width + 12;
    raylib.cdef.DrawText(text.ptr, text_x, label_y - 2, 18, raylib.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });
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

fn drawWinMessage() void {
    const message = "Nivel completado: ¡Recolectaste toda el agua!";
    const sub_message = "Presiona ESC para salir o reinicia para intentar otra ruta";
    const font_size = 28;
    const sub_font_size = 18;

    const text_width = raylib.cdef.MeasureText(message, font_size);
    const sub_width = raylib.cdef.MeasureText(sub_message, sub_font_size);
    const screen_width = raylib.cdef.GetScreenWidth();
    const screen_height = raylib.cdef.GetScreenHeight();

    const box_width = @max(text_width, sub_width) + 60;
    const box_height = font_size + sub_font_size + 40;
    const box_x = @divTrunc(screen_width - box_width, 2);
    const box_y = @divTrunc(screen_height, 2) - box_height;

    raylib.cdef.DrawRectangle(box_x, box_y, box_width, box_height, raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 160 });
    raylib.cdef.DrawRectangleLines(box_x, box_y, box_width, box_height, raylib.Color{ .r = 0, .g = 180, .b = 255, .a = 230 });

    const text_x = @divTrunc(screen_width - text_width, 2);
    const text_y = box_y + 12;
    raylib.cdef.DrawText(message, text_x, text_y, font_size, raylib.Color{ .r = 0, .g = 200, .b = 255, .a = 255 });

    const sub_x = @divTrunc(screen_width - sub_width, 2);
    const sub_y = text_y + font_size + 6;
    raylib.cdef.DrawText(sub_message, sub_x, sub_y, sub_font_size, raylib.Color.white);
}

// Tests removed from main executable to avoid pulling testing deps
