const raylib = @import("raylib");

pub const Direction = enum { back, left, front, right };

pub const AnimKind = enum { idle, walk, run };

pub const FrameGrid = struct {
    image_width: i32,
    image_height: i32,
    frame_width: i32,
    frame_height: i32,
};

pub const AnimationDef = struct {
    start_row: i32, // starting row index of back,left,front,right block
    frames: []const i32, // 1-based frame indices per spec
};

pub const AnimationSet = struct {
    idle: AnimationDef,
    walk: AnimationDef,
    run: AnimationDef,
};

pub const AnimatedSprite = struct {
    texture: raylib.Texture2D,
    grid: FrameGrid,
    set: AnimationSet,
    current: AnimKind = .idle,
    direction: Direction = .front,
    frame_index: i32 = 0,
    frame_time: f32 = 0,
    seconds_per_frame: f32 = 0.1,
    layer: i32 = 0,
    render_scale: f32 = 1.0,

    pub fn getCurrentAnimation(self: *const AnimatedSprite) AnimationDef {
        return switch (self.current) {
            .idle => self.set.idle,
            .walk => self.set.walk,
            .run => self.set.run,
        };
    }

    pub fn calcSourceRect(self: *const AnimatedSprite) raylib.Rectangle {
        const anim = self.getCurrentAnimation();
        const row_block = anim.start_row;
        const dir_offset: i32 = switch (self.direction) {
            .back => 0,
            .left => 1,
            .front => 2,
            .right => 3,
        };
        const row = row_block + dir_offset;
        const frames = anim.frames;
        var idx = self.frame_index;
        if (idx < 0) idx = 0;
        if (idx >= @as(i32, @intCast(frames.len))) idx = @as(i32, @intCast(frames.len - 1));
        const idx_usize: usize = @intCast(idx);
        const col_1based = frames[idx_usize];
        const col = if (col_1based <= 0) 0 else col_1based - 1;
        return raylib.Rectangle{
            .x = @floatFromInt(col * self.grid.frame_width),
            .y = @floatFromInt(row * self.grid.frame_height),
            .width = @floatFromInt(self.grid.frame_width),
            .height = @floatFromInt(self.grid.frame_height),
        };
    }
};
