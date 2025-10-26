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

    // Initialize debug render system
    var debug_system = DebugRenderSystem.DebugRenderSystem{};
    var input_system = InputSystem.InputSystem.init(&debug_system);

    var last_time: f32 = @floatCast(raylib.cdef.GetTime());

    while (!raylib.cdef.WindowShouldClose()) {
        const now: f32 = @floatCast(raylib.cdef.GetTime());
        const dt: f32 = now - last_time;
        last_time = now;

        // Update systems
        input_system.update(&world, dt);
        MovementSystem.MovementSystem.update(&world, dt);
        AnimationSystem.AnimationSystem.syncDirectionAndState(&world, player);
        AnimationSystem.AnimationSystem.update(&world, dt);
        // Update camera effects/follow
        CameraSystem.CameraSystem.update(&world, dt);

        // Draw
        raylib.cdef.BeginDrawing();
        defer raylib.cdef.EndDrawing();
        raylib.cdef.ClearBackground(raylib.Color.ray_white);
        // 2D world rendering under camera
        CameraSystem.CameraSystem.begin2D(&world, cam_e);
        defer CameraSystem.CameraSystem.end2D();
        // Draw tilemap first (water then grass per cell)
        TilemapRenderSystem.TilemapRenderSystem.draw(&world);
        // Draw special tiles (always visible)
        SpecialTilesRenderSystem.SpecialTilesRenderSystem.draw(&world);
        try RenderSystem.RenderSystem.draw(&world);

        // Draw debug overlay if enabled
        debug_system.draw(&world);

        // Draw UI text
        raylib.cdef.DrawText("F1 - Toggle Debug Overlay", 10, 10, 20, raylib.Color.black);
        if (debug_system.show_debug) {
            raylib.cdef.DrawText("Debug: ON (Green=Walkable, Red=Non-walkable)", 10, 35, 16, raylib.Color.red);
            raylib.cdef.DrawText("Player collision points shown as small circles", 10, 55, 14, raylib.Color.blue);
        }
    }
}

// Tests removed from main executable to avoid pulling testing deps
