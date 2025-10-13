const std = @import("std");
const ComponentStore = @import("ComponentStore.zig");
const TilemapMod = @import("components/TileMap.zig");
const CameraComp = @import("components/Camera2D.zig");

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
    camera_store: ComponentStore.ComponentStore(CameraComp.Camera2D),

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
            .camera_store = ComponentStore.ComponentStore(CameraComp.Camera2D).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Free nested allocations first
        var it = self.tilemap_store.iterator();
        while (it.next()) |entry| {
            var tm = entry.value_ptr;
            tm.deinit(self.allocator);
        }
        self.transform_store.deinit();
        self.velocity_store.deinit();
        self.sprite_store.deinit();
        self.background_store.deinit();
        self.z_index_store.deinit();
        self.tilemap_store.deinit();
        self.camera_store.deinit();
    }

    pub fn create(self: *Self) Entity {
        const id = self.next_entity;
        self.next_entity += 1;
        return id;
    }
};
