const std = @import("std");

pub fn ComponentStore(comptime T: type) type {
    return struct {
        const Self = @This();

        map: std.AutoHashMap(u32, T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(u32, T).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn set(self: *Self, entity: u32, value: T) !void {
            try self.map.put(entity, value);
        }

        pub fn get(self: *Self, entity: u32) ?T {
            return self.map.get(entity);
        }

        pub fn getPtr(self: *Self, entity: u32) ?*T {
            return self.map.getPtr(entity);
        }

        pub fn remove(self: *Self, entity: u32) void {
            _ = self.map.remove(entity);
        }

        pub fn contains(self: *Self, entity: u32) bool {
            return self.map.contains(entity);
        }

        pub fn iterator(self: *Self) std.AutoHashMap(u32, T).Iterator {
            return self.map.iterator();
        }
    };
}

pub fn TagStore() type {
    return struct {
        const Self = @This();

        map: std.AutoHashMap(u32, void),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(u32, void).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn add(self: *Self, entity: u32) !void {
            try self.map.put(entity, {});
        }

        pub fn remove(self: *Self, entity: u32) void {
            _ = self.map.remove(entity);
        }

        pub fn contains(self: *Self, entity: u32) bool {
            return self.map.contains(entity);
        }

        pub fn iterator(self: *Self) std.AutoHashMap(u32, void).Iterator {
            return self.map.iterator();
        }
    };
}
