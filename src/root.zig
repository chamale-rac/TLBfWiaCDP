//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");

/// Public ECS API surface for other modules if needed later
pub const ecs = struct {
    pub const Entity = u32;
};
