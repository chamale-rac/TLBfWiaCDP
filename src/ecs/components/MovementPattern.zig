const std = @import("std");

pub const PatternType = enum {
    tracking, // Chase the player
    circular, // Orbit around a point
    patrol, // Move between waypoints
    stationary, // Don't move (default)
};

pub const MovementPattern = struct {
    pattern_type: PatternType = .stationary,

    // Common parameters
    speed: f32 = 50.0,

    // Tracking parameters
    tracking_lerp_speed: f32 = 2.0, // Smoothness of tracking (higher = more direct)

    // Circular parameters
    orbit_center_x: f32 = 0.0,
    orbit_center_y: f32 = 0.0,
    orbit_radius: f32 = 100.0,
    orbit_speed: f32 = 1.0, // Radians per second
    orbit_angle: f32 = 0.0, // Current angle
    orbit_clockwise: bool = true,

    // Patrol parameters
    waypoints: ?[]const Waypoint = null,
    current_waypoint_index: usize = 0,
    patrol_pause_time: f32 = 0.0, // Time to wait at each waypoint
    patrol_pause_timer: f32 = 0.0,
    patrol_loop: bool = true, // Loop back to start or ping-pong
    patrol_reverse: bool = false, // For ping-pong mode

    pub const Waypoint = struct {
        x: f32,
        y: f32,
    };

    pub fn deinit(self: *MovementPattern, allocator: std.mem.Allocator) void {
        if (self.waypoints) |waypoints| {
            allocator.free(waypoints);
            self.waypoints = null;
        }
    }

    /// Set circular orbit center (useful for orbiting player)
    pub fn setOrbitCenter(self: *MovementPattern, x: f32, y: f32) void {
        self.orbit_center_x = x;
        self.orbit_center_y = y;
    }

    /// Initialize circular pattern around current position
    pub fn initCircularAroundPoint(self: *MovementPattern, center_x: f32, center_y: f32, radius: f32, speed: f32, clockwise: bool) void {
        self.pattern_type = .circular;
        self.orbit_center_x = center_x;
        self.orbit_center_y = center_y;
        self.orbit_radius = radius;
        self.orbit_speed = speed;
        self.orbit_clockwise = clockwise;
        self.orbit_angle = 0.0;
    }

    /// Get next waypoint in patrol
    pub fn advanceWaypoint(self: *MovementPattern) void {
        if (self.waypoints) |waypoints| {
            if (waypoints.len == 0) return;

            if (self.patrol_loop) {
                // Loop mode: go back to start
                self.current_waypoint_index = (self.current_waypoint_index + 1) % waypoints.len;
            } else {
                // Ping-pong mode
                if (self.patrol_reverse) {
                    if (self.current_waypoint_index == 0) {
                        self.patrol_reverse = false;
                        self.current_waypoint_index = 1;
                    } else {
                        self.current_waypoint_index -= 1;
                    }
                } else {
                    if (self.current_waypoint_index + 1 >= waypoints.len) {
                        self.patrol_reverse = true;
                        if (waypoints.len > 1) {
                            self.current_waypoint_index = waypoints.len - 2;
                        }
                    } else {
                        self.current_waypoint_index += 1;
                    }
                }
            }

            // Reset pause timer
            self.patrol_pause_timer = 0.0;
        }
    }
};
