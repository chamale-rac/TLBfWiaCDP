// GameTimer component - tracks game/survival time
pub const GameTimer = struct {
    elapsed_time: f32 = 0.0,
    is_running: bool = true,

    pub fn update(self: *GameTimer, dt: f32) void {
        if (self.is_running) {
            self.elapsed_time += dt;
        }
    }

    pub fn reset(self: *GameTimer) void {
        self.elapsed_time = 0.0;
    }

    pub fn pause(self: *GameTimer) void {
        self.is_running = false;
    }

    pub fn unpause(self: *GameTimer) void {
        self.is_running = true;
    }

    pub fn getMinutes(self: *const GameTimer) i32 {
        return @intFromFloat(@floor(self.elapsed_time / 60.0));
    }

    pub fn getSeconds(self: *const GameTimer) i32 {
        return @intFromFloat(@floor(@mod(self.elapsed_time, 60.0)));
    }
};
