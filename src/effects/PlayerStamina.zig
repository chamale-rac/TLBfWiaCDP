pub const PlayerStamina = struct {
    max: f32,
    current: f32,
    drain_per_second: f32,
    regen_per_second: f32,
    regen_delay: f32,
    regen_cooldown: f32 = 0.0,

    pub fn init(max: f32, drain_per_second: f32, regen_per_second: f32, regen_delay: f32) PlayerStamina {
        const clamped_max = if (max <= 0) 1 else max;
        return .{
            .max = clamped_max,
            .current = clamped_max,
            .drain_per_second = if (drain_per_second <= 0) 1 else drain_per_second,
            .regen_per_second = if (regen_per_second <= 0) 1 else regen_per_second,
            .regen_delay = if (regen_delay < 0) 0 else regen_delay,
        };
    }

    pub fn tick(self: *PlayerStamina, is_running: bool, dt: f32) void {
        if (dt <= 0.0) return;

        if (is_running and self.canRun()) {
            self.current -= self.drain_per_second * dt;
            if (self.current < 0.0) self.current = 0.0;
            self.regen_cooldown = self.regen_delay;
        } else {
            if (self.regen_cooldown > 0.0) {
                self.regen_cooldown -= dt;
                if (self.regen_cooldown < 0.0) self.regen_cooldown = 0.0;
            } else {
                self.current += self.regen_per_second * dt;
                if (self.current > self.max) self.current = self.max;
            }
        }
    }

    pub fn canRun(self: PlayerStamina) bool {
        return self.current > 1.0;
    }

    pub fn fraction(self: PlayerStamina) f32 {
        if (self.max <= 0.0) return 0.0;
        return self.current / self.max;
    }
};


