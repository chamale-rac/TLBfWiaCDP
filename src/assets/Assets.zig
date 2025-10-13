const std = @import("std");
const raylib = @import("raylib");

pub const Assets = struct {
    allocator: std.mem.Allocator,
    // Textures
    bg_desert: raylib.Texture2D,
    lpc_player: raylib.Texture2D,
    campfire: raylib.Texture2D,
    water: raylib.Texture2D,
    grass: raylib.Texture2D,

    pub fn load(allocator: std.mem.Allocator) Assets {
        // NOTE: raylib must have InitWindow() called before loading textures
        return .{
            .allocator = allocator,
            .bg_desert = raylib.cdef.LoadTexture("assets/background_desert.png"),
            .lpc_player = raylib.cdef.LoadTexture("assets/lpc_player.png"),
            .campfire = raylib.cdef.LoadTexture("assets/campfire_128x64.png"),
            .water = raylib.cdef.LoadTexture("assets/water.png"),
            .grass = raylib.cdef.LoadTexture("assets/grass.png"),
        };
    }

    pub fn unload(self: *Assets) void {
        raylib.cdef.UnloadTexture(self.bg_desert);
        raylib.cdef.UnloadTexture(self.lpc_player);
        raylib.cdef.UnloadTexture(self.campfire);
        raylib.cdef.UnloadTexture(self.water);
        raylib.cdef.UnloadTexture(self.grass);
    }
};
