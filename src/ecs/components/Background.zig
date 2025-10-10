const raylib = @import("raylib");

pub const Background = struct {
    texture: raylib.Texture2D,
    // For now, just a decorative backdrop.
    // In future: intgrid/tile logic.
};
