const std = @import("std");

pub const TileType = enum(u8) {
    none = 0,
    slowdown = 1,
    speedup = 2,
    push_teleport = 3,
};

pub const SpecialTile = struct {
    x: i32,
    y: i32,
    tile_type: TileType,
};

pub const SpecialTiles = struct {
    const Self = @This();
    width: i32,
    height: i32,
    // Grid storing tile types at each position
    values: std.ArrayListUnmanaged(TileType),
    // List of all special tiles for iteration
    tiles: std.ArrayListUnmanaged(SpecialTile),

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32) !Self {
        var values = std.ArrayListUnmanaged(TileType){};
        try values.ensureTotalCapacity(allocator, @intCast(width * height));
        values.items.len = @intCast(width * height);

        // Initialize all tiles as none by default
        @memset(values.items, .none);

        const tiles = std.ArrayListUnmanaged(SpecialTile){};

        return .{
            .width = width,
            .height = height,
            .values = values,
            .tiles = tiles,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.values.deinit(allocator);
        self.tiles.deinit(allocator);
    }

    pub fn index(self: *const Self, x: i32, y: i32) usize {
        return @intCast(y * self.width + x);
    }

    pub fn get(self: *const Self, x: i32, y: i32) TileType {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return .none; // Out of bounds has no special tile
        }
        const idx = self.index(x, y);
        return self.values.items[idx];
    }

    pub fn set(self: *Self, allocator: std.mem.Allocator, x: i32, y: i32, tile_type: TileType) !void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return; // Ignore out of bounds
        }
        const idx = self.index(x, y);
        const old_type = self.values.items[idx];
        self.values.items[idx] = tile_type;

        // Update tiles list
        if (old_type == .none and tile_type != .none) {
            // Adding a new special tile
            try self.tiles.append(allocator, .{ .x = x, .y = y, .tile_type = tile_type });
        } else if (old_type != .none and tile_type == .none) {
            // Removing a special tile
            var i: usize = 0;
            while (i < self.tiles.items.len) {
                if (self.tiles.items[i].x == x and self.tiles.items[i].y == y) {
                    _ = self.tiles.swapRemove(i);
                    break;
                }
                i += 1;
            }
        } else if (old_type != .none and tile_type != .none and old_type != tile_type) {
            // Changing type of existing special tile
            for (self.tiles.items) |*tile| {
                if (tile.x == x and tile.y == y) {
                    tile.tile_type = tile_type;
                    break;
                }
            }
        }
    }

    pub fn getTileType(self: *const Self, x: i32, y: i32) TileType {
        return self.get(x, y);
    }
};
