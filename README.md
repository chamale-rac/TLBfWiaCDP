# TLBfWiaCDP
The Last Bottle of Water in a Completely Dry Planet | ECS 2D Game

## How to Run

### Prerequisites
- Install [Zig](https://ziglang.org/download/) (version 0.15.1 or later)
  - **Important**: The new raylib-zig organization requires Zig 0.15.1+
  - If you have an older version, please upgrade before building (Refer to https://ziglang.org/learn/getting-started 🙏)

### Build and Run
```bash
# Build the project
zig build

# Run the game
zig build run
```

The executable will be created in `zig-out/bin/` directory.

### Assets

Place the following files under `assets/`:
- `background_desert.png` (decorative scene background)
- `lpc_player.png` (LPC 832x3456, 64x64 frames)
- `campfire_128x64.png` (frames 32x32, second row anim 1-1-2-2-3-3-4-4)

On build, assets are installed to `zig-out/bin/assets/` and loaded at runtime.