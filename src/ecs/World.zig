const std = @import("std");
const ComponentStore = @import("ComponentStore.zig");
const TilemapMod = @import("components/TileMap.zig");
const CameraComp = @import("components/Camera2D.zig");
const IntGridMod = @import("components/IntGrid.zig");
const SpecialTilesMod = @import("components/SpecialTiles.zig");
const EnemyComp = @import("components/Enemy.zig");
const EnemySpawnerComp = @import("components/EnemySpawner.zig");
const GameTimerComp = @import("components/GameTimer.zig");
const MovementPatternComp = @import("components/MovementPattern.zig");
const ProjectileComp = @import("components/Projectile.zig");
const CollectibleComp = @import("components/Collectible.zig");

pub const Entity = u32;

pub const World = struct {
    const Self = @This();

    next_entity: Entity,
    allocator: std.mem.Allocator,

    // Core components
    transform_store: ComponentStore.ComponentStore(@import("components/Transform2D.zig").Transform2D),
    velocity_store: ComponentStore.ComponentStore(@import("components/Velocity2D.zig").Velocity2D),
    sprite_store: ComponentStore.ComponentStore(@import("components/AnimatedSprite.zig").AnimatedSprite),
    background_store: ComponentStore.ComponentStore(@import("components/Background.zig").Background),
    z_index_store: ComponentStore.ComponentStore(@import("components/ZIndex.zig").ZIndex),
    tilemap_store: ComponentStore.ComponentStore(TilemapMod.Tilemap),
    intgrid_store: ComponentStore.ComponentStore(IntGridMod.IntGrid),
    camera_store: ComponentStore.ComponentStore(CameraComp.Camera2D),
    special_tiles_store: ComponentStore.ComponentStore(SpecialTilesMod.SpecialTiles),
    enemy_store: ComponentStore.ComponentStore(EnemyComp.Enemy),
    spawner_store: ComponentStore.ComponentStore(EnemySpawnerComp.EnemySpawner),
    game_timer_store: ComponentStore.ComponentStore(GameTimerComp.GameTimer),
    movement_pattern_store: ComponentStore.ComponentStore(MovementPatternComp.MovementPattern),
    projectile_store: ComponentStore.ComponentStore(ProjectileComp.Projectile),
    collectible_store: ComponentStore.ComponentStore(CollectibleComp.Collectible),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .next_entity = 1,
            .allocator = allocator,
            .transform_store = ComponentStore.ComponentStore(@import("components/Transform2D.zig").Transform2D).init(allocator),
            .velocity_store = ComponentStore.ComponentStore(@import("components/Velocity2D.zig").Velocity2D).init(allocator),
            .sprite_store = ComponentStore.ComponentStore(@import("components/AnimatedSprite.zig").AnimatedSprite).init(allocator),
            .background_store = ComponentStore.ComponentStore(@import("components/Background.zig").Background).init(allocator),
            .z_index_store = ComponentStore.ComponentStore(@import("components/ZIndex.zig").ZIndex).init(allocator),
            .tilemap_store = ComponentStore.ComponentStore(TilemapMod.Tilemap).init(allocator),
            .intgrid_store = ComponentStore.ComponentStore(IntGridMod.IntGrid).init(allocator),
            .camera_store = ComponentStore.ComponentStore(CameraComp.Camera2D).init(allocator),
            .special_tiles_store = ComponentStore.ComponentStore(SpecialTilesMod.SpecialTiles).init(allocator),
            .enemy_store = ComponentStore.ComponentStore(EnemyComp.Enemy).init(allocator),
            .spawner_store = ComponentStore.ComponentStore(EnemySpawnerComp.EnemySpawner).init(allocator),
            .game_timer_store = ComponentStore.ComponentStore(GameTimerComp.GameTimer).init(allocator),
            .movement_pattern_store = ComponentStore.ComponentStore(MovementPatternComp.MovementPattern).init(allocator),
            .projectile_store = ComponentStore.ComponentStore(ProjectileComp.Projectile).init(allocator),
            .collectible_store = ComponentStore.ComponentStore(CollectibleComp.Collectible).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Free nested allocations first
        var it = self.tilemap_store.iterator();
        while (it.next()) |entry| {
            var tm = entry.value_ptr;
            tm.deinit(self.allocator);
        }

        var intgrid_it = self.intgrid_store.iterator();
        while (intgrid_it.next()) |entry| {
            var intgrid = entry.value_ptr;
            intgrid.deinit(self.allocator);
        }

        var special_tiles_it = self.special_tiles_store.iterator();
        while (special_tiles_it.next()) |entry| {
            var special_tiles = entry.value_ptr;
            special_tiles.deinit(self.allocator);
        }

        self.transform_store.deinit();
        self.velocity_store.deinit();
        self.sprite_store.deinit();
        self.background_store.deinit();
        self.z_index_store.deinit();
        self.tilemap_store.deinit();
        self.intgrid_store.deinit();
        self.camera_store.deinit();
        self.special_tiles_store.deinit();
        self.enemy_store.deinit();
        self.spawner_store.deinit();
        self.game_timer_store.deinit();
        self.projectile_store.deinit();
        self.collectible_store.deinit();

        // Free movement pattern waypoints
        var movement_it = self.movement_pattern_store.iterator();
        while (movement_it.next()) |entry| {
            var pattern = entry.value_ptr;
            pattern.deinit(self.allocator);
        }
        self.movement_pattern_store.deinit();
    }

    pub fn create(self: *Self) Entity {
        const id = self.next_entity;
        self.next_entity += 1;
        return id;
    }
};
