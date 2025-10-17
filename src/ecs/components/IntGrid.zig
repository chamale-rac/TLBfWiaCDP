const std = @import("std");

pub const IntGridValue = enum(u8) {
    walkable_ground = 1,
    non_walkable_water = 0,
};

pub const IntGrid = struct {
    const Self = @This();
    width: i32,
    height: i32,
    values: std.ArrayListUnmanaged(IntGridValue),

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32) !Self {
        var values = std.ArrayListUnmanaged(IntGridValue){};
        try values.ensureTotalCapacity(allocator, @intCast(width * height));
        values.items.len = @intCast(width * height);

        // Initialize all tiles as non-walkable by default
        @memset(values.items, .non_walkable_water);

        return .{
            .width = width,
            .height = height,
            .values = values,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.values.deinit(allocator);
    }

    pub fn index(self: *const Self, x: i32, y: i32) usize {
        return @intCast(y * self.width + x);
    }

    pub fn get(self: *const Self, x: i32, y: i32) IntGridValue {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return .non_walkable_water; // Out of bounds is non-walkable
        }
        const idx = self.index(x, y);
        return self.values.items[idx];
    }

    pub fn set(self: *Self, x: i32, y: i32, value: IntGridValue) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return; // Ignore out of bounds
        }
        const idx = self.index(x, y);
        self.values.items[idx] = value;
    }

    pub fn isWalkable(self: *const Self, x: i32, y: i32) bool {
        return self.get(x, y) == .walkable_ground;
    }

    pub fn isNonWalkable(self: *const Self, x: i32, y: i32) bool {
        return self.get(x, y) == .non_walkable_water;
    }
};
