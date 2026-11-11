# Dolphin FSR Edition (experimental)

Independent development branch for an optional high-quality presentation/upscaling path in Dolphin. The original `master` branch is left untouched.

## Hardware target

Initial target machine: Windows laptop, NVIDIA GeForce RTX 3060 Laptop GPU, AMD Ryzen 7 4800H, 16 GB RAM, 1920x1080 display. These are the user's reported specifications; performance must be measured on the actual machine.

## Current implementation status

- [x] Dedicated branch: `fsr3-frame-generation`.
- [x] First experimental spatial post-processing shader: `FSR_Spatial.glsl`.
- [ ] Integrate a true AMD FidelityFX Super Resolution implementation (FSR 1 EASU/RCAS or a maintained SDK integration).
- [ ] Add a dedicated Dolphin settings page and quality/performance presets.
- [ ] Implement and validate FSR 2/3 temporal upscaling only if reliable motion vectors, depth, jitter and frame history can be supplied by the emulator.
- [ ] Frame generation 2x: research and architecture only. Not implemented.
- [ ] D3D12 and Vulkan validation.
- [ ] Windows build, packaging and runtime testing.

## Important technical distinction

The included shader is an original, lightweight, edge-adaptive spatial reconstruction experiment. It is **not** AMD FidelityFX Super Resolution 1/2/3, does not use temporal accumulation, and does not generate intermediate frames. It is exposed through Dolphin's existing post-processing shader mechanism and is intended for visual evaluation only.

FSR 2/3 temporal upscaling requires motion vectors, depth, jitter metadata and a history pipeline. A post-processing shader that only sees the final color image cannot reconstruct those inputs reliably.

Frame generation is a separate subsystem. Even a successful 2x frame-generation path does not increase emulated CPU/game logic speed: 30 real emulation FPS plus generated intermediate images may display 60 images per second while the game simulation still advances at 30 FPS. Input latency and artifacts must be measured.

## Try the current shader

1. Build this branch using Dolphin's normal Windows build instructions.
2. Copy `Data/Sys/Shaders/FSR_Spatial.glsl` into the build's system shader directory (or the user shader directory).
3. Open Graphics > Enhancements > Post-Processing Effect and select `FSR_Spatial`.
4. Compare against post-processing off at the same internal and output resolutions.

The shader is a prototype. If it is not listed, check the Dolphin log for shader discovery or compilation errors. It is not a standalone executable and has not yet been built or tested in Dolphin in this development environment.

## Safe performance baseline for the target laptop

- Backend: test Direct3D 12 and Vulkan separately; keep the one with fewer frame-time spikes and correct graphics for the game.
- Internal resolution: begin at 2x or 3x native, then test 4x only if GPU headroom remains.
- V-Sync: test both states; do not use frame generation to hide emulation-speed drops.
- Shader compilation: enable the shader cache and avoid changing several settings between comparisons.
- Record real emulation speed, frame time, GPU utilization, VRAM use and temperatures.

The requested 5K/8K/above-8K output modes are experimental stress tests, not performance promises. A 1080p panel cannot display their additional output detail directly, and very high EFB scales can exhaust VRAM or cause severe slowdown.

## Licensing

Dolphin is GPL-2.0-or-later. This branch must preserve Dolphin's licensing and include the required license notices for any third-party FidelityFX code or SDK added later. The current shader is original experimental code and does not contain AMD SDK source.
