const std = @import("std");

/// Tracks the player's lives and temporary invulnerability state after taking damage.
pub const PlayerHealth = struct {
    max_hearts: u8 = 3,
    current_hearts: u8 = 3,

    /// Remaining seconds of invulnerability after a hit.
    invulnerable_timer: f32 = 0.0,

    /// Accumulates time to toggle the blink effect.
    blink_accumulator: f32 = 0.0,
    /// True when the sprite should be tinted red for blink feedback.
    blink_is_red: bool = false,

    pub const INVULNERABLE_DURATION: f32 = 1.25;
    pub const BLINK_INTERVAL: f32 = 0.1;

    /// Apply damage if not already invulnerable. Returns true if damage was taken.
    pub fn takeDamage(self: *PlayerHealth, amount: u8) bool {
        if (amount == 0 or self.current_hearts == 0 or self.isInvulnerable()) return false;

        const dmg = std.math.min(amount, self.current_hearts);
        self.current_hearts -= dmg;
        self.beginInvulnerability();
        return true;
    }

    /// Advance timers and maintain blink state.
    pub fn updateTimers(self: *PlayerHealth, dt: f32) void {
        if (self.invulnerable_timer <= 0) return;

        self.invulnerable_timer -= dt;
        if (self.invulnerable_timer < 0) {
            self.invulnerable_timer = 0;
        }

        self.blink_accumulator += dt;
        while (self.blink_accumulator >= BLINK_INTERVAL) {
            self.blink_accumulator -= BLINK_INTERVAL;
            self.blink_is_red = !self.blink_is_red;
        }

        if (self.invulnerable_timer == 0) {
            self.resetBlink();
        }
    }

    pub inline fn isInvulnerable(self: PlayerHealth) bool {
        return self.invulnerable_timer > 0;
    }

    pub fn beginInvulnerability(self: *PlayerHealth) void {
        self.invulnerable_timer = INVULNERABLE_DURATION;
        self.blink_accumulator = 0;
        self.blink_is_red = true;
    }

    pub fn resetBlink(self: *PlayerHealth) void {
        self.blink_accumulator = 0;
        self.blink_is_red = false;
    }
};
