const std = @import("std");
const raylib = @import("raylib");

pub const TileType = enum { water, grass };

pub const Tile = struct {
    ttype: TileType,
    needs_autotiling: bool = false,
    // Source coordinates (pixels) within the grass tileset (16x16 tiles)
    sx: i32 = 0,
    sy: i32 = 0,
};

pub const Tilemap = struct {
    const Self = @This();
    width: i32,
    height: i32,
    tile_size: i32 = 16,
    scale: f32 = 3.0,
    water_texture: raylib.Texture2D,
    grass_texture: raylib.Texture2D,
    tiles: std.ArrayListUnmanaged(Tile),

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.tiles.deinit(allocator);
    }

    pub fn index(self: *const Self, x: i32, y: i32) usize {
        return @intCast(y * self.width + x);
    }
};
