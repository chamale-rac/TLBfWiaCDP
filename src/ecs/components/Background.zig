const raylib = @import("raylib");

pub const Background = struct {
    texture: raylib.Texture2D,
    repeat: bool = false,
    // For now, just a decorative backdrop.
    // In future: intgrid/tile logic.
};
