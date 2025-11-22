pub const CollectibleKind = enum {
    bottle,
};

pub const Collectible = struct {
    kind: CollectibleKind = .bottle,
    width: f32,
    height: f32,
};

