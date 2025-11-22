// Enemy component - marks entities as enemies
pub const Enemy = struct {
    // Enemy type identifier
    enemy_type: EnemyType = .mouse,
    // Current AI state
    ai_state: AIState = .idle,
    // Speed multiplier for this enemy
    speed: f32 = 50.0,
    // Time accumulator for AI state changes
    state_timer: f32 = 0.0,
    // Next state change time
    next_state_change: f32 = 2.0,
    // Spawner entity that created this enemy (for bookkeeping)
    spawner_entity: ?u32 = null,

    pub const EnemyType = enum {
        mouse,
        rabbit,
        sheep,
        wolf,
        lizard,
    };

    pub const AIState = enum {
        idle,
        wander,
        // Add patrol, chase, etc. in the future
    };
};
