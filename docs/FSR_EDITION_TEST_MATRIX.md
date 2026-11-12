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
| G | D3D12 | 2x | 1080p | FSR1_RCAS (stops 1.0) | | | | | | |
| H | Vulkan | 2x | 1080p | FSR1_RCAS (stops 1.0) | | | | | | |
| I | D3D12 | 2x | 1080p | FSR1_EASU | | | | | | |
| J | Vulkan | 2x | 1080p | FSR1_EASU | | | | | | |
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


## RCAS-specific checks

- Compare RCAS off and on at identical output resolution; do not compare the standalone RCAS shader to EASU as if they were the same operation.
- Test sharpness stops 0, 1, 2 and 4; inspect halos, ringing, noise amplification and clipped highlights/shadows.
- Check image borders and all four corners for sampling seams.
- Verify alpha/UI edges remain intact and the filter does not change the output dimensions.
- RCAS is currently standalone; do not record an EASU+RCAS combined result until a true two-pass pipeline exists.

## Frame-generation readiness gates

Do not begin user-facing 2x frame-generation tests until all of these are available:
- Stable real emulation speed of at least 60 FPS in the target scene for the preferred FSR 3.1.x quality target; also document behavior at 30 FPS as a lower-bound experiment.
- Correct render-resolution motion vectors and depth with documented formats, scale, jitter convention and camera-cut handling.
- A way to separate or correctly recompose the game's UI/HUD on generated frames.
- D3D12 and Vulkan swapchain lifecycle integration, including resize, fullscreen/windowed transitions, device loss and shutdown.
- Separate counters for emulated real frames, generated frames and presented frames.
- Correct frame pacing and latency measurements; generated FPS must not conceal a drop in real emulation speed.

AMD's FSR 3.1.7 guidance recommends 60 FPS or higher input for optimal frame generation and notes that it can function at 30 FPS with potentially worse pacing/artifacts. The 60 FPS input gate is therefore the preferred target for the RTX 3060 laptop test plan.


## FPS counter validation

- [ ] Confirm Unique VI FPS excludes duplicate Video Interface presentations.
- [ ] Confirm Output FPS includes all presentation callbacks.
- [ ] Verify pause/resume and state-load counter reset/invalidation behavior.
- [ ] When frame generation is implemented, add a third counter at the generated-frame submission/presentation point; never derive it by multiplying Unique VI FPS.
