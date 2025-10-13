const std = @import("std");
const WorldMod = @import("../World.zig");
const TilemapComp = @import("../components/TileMap.zig");

const dx = [_]i32{ -1, 0, 1, -1, 1, -1, 0, 1 };
const dy = [_]i32{ -1, -1, -1, 0, 0, 1, 1, 1 };

// mapping of bitmask -> list of (sx,sy) in the 16x16 grass sheet
// The provided C++ table used absolute pixel coords; keep same values.
const Choice = struct { sx: i32, sy: i32 };
const Entry = []const Choice;

const table = std.StaticStringMap(Entry).initComptime(.{
    .{ "2", &[_]Choice{.{ .sx = 0, .sy = 80 }} },
    .{ "8", &[_]Choice{.{ .sx = 48, .sy = 96 }} },
    .{ "10", &[_]Choice{.{ .sx = 80, .sy = 112 }} },
    .{ "11", &[_]Choice{.{ .sx = 48, .sy = 80 }} },
    .{ "16", &[_]Choice{.{ .sx = 0, .sy = 96 }} },
    .{ "18", &[_]Choice{.{ .sx = 64, .sy = 112 }} },
    .{ "22", &[_]Choice{.{ .sx = 16, .sy = 80 }} },
    .{ "24", &[_]Choice{ .{ .sx = 16, .sy = 96 }, .{ .sx = 32, .sy = 96 } } },
    .{ "26", &[_]Choice{.{ .sx = 144, .sy = 32 }} },
    .{ "27", &[_]Choice{.{ .sx = 144, .sy = 80 }} },
    .{ "30", &[_]Choice{.{ .sx = 96, .sy = 80 }} },
    .{ "31", &[_]Choice{.{ .sx = 32, .sy = 80 }} },
    .{ "64", &[_]Choice{.{ .sx = 0, .sy = 32 }} },
    .{ "66", &[_]Choice{ .{ .sx = 0, .sy = 48 }, .{ .sx = 0, .sy = 64 } } },
    .{ "72", &[_]Choice{.{ .sx = 80, .sy = 96 }} },
    .{ "74", &[_]Choice{.{ .sx = 128, .sy = 32 }} },
    .{ "75", &[_]Choice{.{ .sx = 112, .sy = 80 }} },
    .{ "80", &[_]Choice{.{ .sx = 64, .sy = 96 }} },
    .{ "82", &[_]Choice{.{ .sx = 144, .sy = 48 }} },
    .{ "86", &[_]Choice{.{ .sx = 128, .sy = 80 }} },
    .{ "88", &[_]Choice{.{ .sx = 128, .sy = 48 }} },
    .{ "90", &[_]Choice{ .{ .sx = 0, .sy = 112 }, .{ .sx = 16, .sy = 112 } } },
    .{ "91", &[_]Choice{.{ .sx = 32, .sy = 112 }} },
    .{ "94", &[_]Choice{.{ .sx = 96, .sy = 48 }} },
    .{ "95", &[_]Choice{.{ .sx = 96, .sy = 112 }} },
    .{ "104", &[_]Choice{.{ .sx = 48, .sy = 48 }} },
    .{ "106", &[_]Choice{.{ .sx = 144, .sy = 64 }} },
    .{ "107", &[_]Choice{.{ .sx = 48, .sy = 64 }} },
    .{ "120", &[_]Choice{.{ .sx = 112, .sy = 64 }} },
    .{ "122", &[_]Choice{.{ .sx = 48, .sy = 112 }} },
    .{ "123", &[_]Choice{.{ .sx = 112, .sy = 112 }} },
    .{ "126", &[_]Choice{.{ .sx = 48, .sy = 112 }} },
    .{ "127", &[_]Choice{.{ .sx = 64, .sy = 64 }} },
    .{ "208", &[_]Choice{.{ .sx = 16, .sy = 48 }} },
    .{ "210", &[_]Choice{.{ .sx = 96, .sy = 64 }} },
    .{ "214", &[_]Choice{.{ .sx = 16, .sy = 64 }} },
    .{ "216", &[_]Choice{.{ .sx = 128, .sy = 64 }} },
    .{ "218", &[_]Choice{.{ .sx = 96, .sy = 32 }} },
    .{ "219", &[_]Choice{.{ .sx = 32, .sy = 112 }} },
    .{ "222", &[_]Choice{.{ .sx = 96, .sy = 96 }} },
    .{ "223", &[_]Choice{.{ .sx = 80, .sy = 64 }} },
    .{ "248", &[_]Choice{.{ .sx = 32, .sy = 48 }} },
    .{ "250", &[_]Choice{.{ .sx = 112, .sy = 96 }} },
    .{ "251", &[_]Choice{.{ .sx = 64, .sy = 80 }} },
    .{ "254", &[_]Choice{.{ .sx = 80, .sy = 80 }} },
    .{ "255", &[_]Choice{
        .{ .sx = 0, .sy = 0 },   .{ .sx = 16, .sy = 0 },  .{ .sx = 32, .sy = 0 },  .{ .sx = 48, .sy = 0 },  .{ .sx = 64, .sy = 0 },  .{ .sx = 80, .sy = 0 },
        .{ .sx = 0, .sy = 16 },  .{ .sx = 16, .sy = 16 }, .{ .sx = 32, .sy = 16 }, .{ .sx = 48, .sy = 16 }, .{ .sx = 64, .sy = 16 }, .{ .sx = 80, .sy = 16 },
        .{ .sx = 32, .sy = 64 },
    } },
    .{ "0", &[_]Choice{ .{ .sx = 16, .sy = 32 }, .{ .sx = 32, .sy = 32 }, .{ .sx = 48, .sy = 32 }, .{ .sx = 64, .sy = 32 }, .{ .sx = 80, .sy = 32 }, .{ .sx = 64, .sy = 48 }, .{ .sx = 80, .sy = 48 } } },
});

fn pickChoice(mask: u8, x: i32, y: i32) Choice {
    var buf: [4]u8 = undefined;
    const slice = std.fmt.bufPrintZ(&buf, "{d}", .{mask}) catch unreachable;
    if (table.get(slice)) |choices| {
        if (choices.len == 1) return choices[0];
        const ux: u32 = @bitCast(x);
        const uy: u32 = @bitCast(y);
        const seed_u32: u32 = (ux ^ (uy << 1) ^ @as(u32, mask)) % @as(u32, @intCast(choices.len));
        const seed: usize = @intCast(seed_u32);
        return choices[seed];
    }
    return .{ .sx = 0, .sy = 0 };
}

pub const AutoTilingSystem = struct {
    pub fn setup(world: *WorldMod.World) void {
        var tm_it = world.tilemap_store.iterator();
        while (tm_it.next()) |entry| {
            var tm = entry.value_ptr;
            var y: i32 = 0;
            while (y < tm.height) : (y += 1) {
                var x: i32 = 0;
                while (x < tm.width) : (x += 1) {
                    const idx = tm.index(x, y);
                    var tile = &tm.tiles.items[idx];
                    if (!tile.needs_autotiling or tile.ttype != .grass) continue;

                    var mask: u8 = 0;
                    var i: usize = 0;
                    while (i < 8) : (i += 1) {
                        const nx = x + dx[i];
                        const ny = y + dy[i];
                        if (nx < 0 or nx >= tm.width or ny < 0 or ny >= tm.height) continue;

                        // For diagonal neighbors, only allow connectivity if both adjacent
                        // orthogonal neighbors are the same type as the diagonal neighbor.
                        if (i == 0 or i == 2 or i == 5 or i == 7) {
                            const corner_dx: i32 = switch (i) {
                                0 => 1,
                                2 => -1,
                                5 => 1,
                                7 => -1,
                                else => 0,
                            };
                            const corner_dy: i32 = switch (i) {
                                0 => 1,
                                2 => 1,
                                5 => -1,
                                7 => -1,
                                else => 0,
                            };
                            const nx1 = nx + corner_dx;
                            const ny1 = ny + 0;
                            const nx2 = nx + 0;
                            const ny2 = ny + corner_dy;
                            if (nx1 < 0 or nx1 >= tm.width or ny1 < 0 or ny1 >= tm.height or
                                nx2 < 0 or nx2 >= tm.width or ny2 < 0 or ny2 >= tm.height)
                            {
                                continue;
                            }
                            const nidx_diag = tm.index(nx, ny);
                            const neighbor_type = tm.tiles.items[nidx_diag].ttype;
                            const nidx1 = tm.index(nx1, ny1);
                            const nidx2 = tm.index(nx2, ny2);
                            if (tm.tiles.items[nidx1].ttype != neighbor_type or tm.tiles.items[nidx2].ttype != neighbor_type) {
                                continue;
                            }
                        }

                        const nidx = tm.index(nx, ny);
                        const ntile = tm.tiles.items[nidx];
                        if (ntile.ttype == tile.ttype) {
                            mask |= @as(u8, 1) << @intCast(i);
                        }
                    }
                    const choice = pickChoice(mask, x, y);
                    tile.sx = choice.sx;
                    tile.sy = choice.sy;
                    tile.needs_autotiling = false;
                }
            }
        }
    }
};
