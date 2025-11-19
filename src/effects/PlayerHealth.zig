pub const PlayerHealth = struct {
    max_hearts: u8,
    current_hearts: u8,

    invulnerability_duration: f32 = 1.5,
    invulnerability_timer: f32 = 0.0,

    blink_interval: f32 = 0.12,
    blink_timer: f32 = 0.0,
    blink_phase_red: bool = false,
    blink_duration_timer: f32 = 0.0,

    pub fn init(max_hearts: u8) PlayerHealth {
        const hearts = if (max_hearts == 0) 1 else max_hearts;
        return .{
            .max_hearts = hearts,
            .current_hearts = hearts,
        };
    }

    pub fn update(self: *PlayerHealth, dt: f32) void {
        if (self.invulnerability_timer > 0.0) {
            self.invulnerability_timer -= dt;
            if (self.invulnerability_timer < 0.0) self.invulnerability_timer = 0.0;
        }

        if (self.blink_duration_timer > 0.0) {
            self.blink_duration_timer -= dt;
            if (self.blink_duration_timer < 0.0) self.blink_duration_timer = 0.0;

            self.blink_timer += dt;
            if (self.blink_timer >= self.blink_interval) {
                self.blink_timer = 0.0;
                self.blink_phase_red = !self.blink_phase_red;
            }
        } else {
            self.blink_timer = 0.0;
            self.blink_phase_red = false;
        }
    }

    pub fn applyDamage(self: *PlayerHealth, amount: u8) bool {
        if (self.isDead() or self.isInvulnerable()) {
            return false;
        }

        const actual = if (amount > self.current_hearts) self.current_hearts else amount;
        self.current_hearts -= actual;

        self.invulnerability_timer = self.invulnerability_duration;
        self.blink_duration_timer = self.invulnerability_duration;
        self.blink_timer = 0.0;
        self.blink_phase_red = true;

        return true;
    }

    pub fn isInvulnerable(self: PlayerHealth) bool {
        return self.invulnerability_timer > 0.0;
    }

    pub fn isBlinking(self: PlayerHealth) bool {
        return self.blink_duration_timer > 0.0;
    }

    pub fn isBlinkPhaseRed(self: PlayerHealth) bool {
        return self.blink_phase_red;
    }

    pub fn isDead(self: PlayerHealth) bool {
        return self.current_hearts == 0;
    }

    pub fn getHearts(self: PlayerHealth) struct { current: u8, max: u8 } {
        return .{ .current = self.current_hearts, .max = self.max_hearts };
    }

    pub fn reset(self: *PlayerHealth) void {
        self.current_hearts = self.max_hearts;
        self.invulnerability_timer = 0.0;
        self.blink_duration_timer = 0.0;
        self.blink_timer = 0.0;
        self.blink_phase_red = false;
    }
};

