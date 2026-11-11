# FSR Edition validation matrix

Use this sheet after building the branch. Do not compare different games or scenes when measuring frame pacing.

## Target system

- GPU: NVIDIA GeForce RTX 3060 Laptop GPU
- CPU: AMD Ryzen 7 4800H
- RAM: 16 GB
- Display: 1920 x 1080
- Game: Resident Evil 4 Wii PAL (RB4P08), plus one light and one demanding reference game

## Test runs

| Run | Backend | Internal scale | Output size | Post-process | Real emulation speed | Display FPS | Avg frame time | 1% low | VRAM | Artifacts |
|---|---|---:|---|---|---:|---:|---:|---:|---:|---|
| A | D3D12 | 2x | 1080p | Off | | | | | | |
| B | Vulkan | 2x | 1080p | Off | | | | | | |
| C | D3D12 | 2x | 1080p | Edge sharpen prototype | | | | | | |
| D | Vulkan | 2x | 1080p | Edge sharpen prototype | | | | | | |
| E | D3D12 | 3x | 1080p | Off | | | | | | |
| F | Vulkan | 3x | 1080p | Off | | | | | | |

## Scene checklist

- Boot and title menu.
- Resident Evil 4 Wii prologue and opening cutscene.
- Normal gameplay with Leon moving and camera turning.
- Several Ganados on screen, including enemy defeat and item drops.
- Inventory and map.
- Hunnigan codec communication.
- Pause/resume and window resize.
- Backend switch after fully closing and restarting Dolphin.

## Acceptance criteria

- Emulation speed remains at 100% (or the configured target) without frame-generation masking a slowdown.
- No black frames, flicker, missing objects, persistent ghost trails or shader compilation errors.
- Input remains responsive.
- Record real emulation FPS separately from any generated presentation FPS.
- D3D12 and Vulkan are judged independently; do not assume equal behavior.

## Frame generation measurements (only after implementation)

Record both real emulation FPS and displayed FPS. Compare latency and visual artifacts with frame generation off/on in the same scene. Test UI, subtitles, inventory, camera cuts, pause menus, fast motion and scene transitions. Reject the implementation if it produces misleading FPS reporting or unacceptable input latency.

## Resolution stress testing

Try output resolutions above the physical 1080p panel only as controlled stress tests. Keep output size separate from EFB/internal resolution. Increase internal scale one step at a time while monitoring VRAM and frame time; do not force extreme allocations by default.
