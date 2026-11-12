# Dolphin FSR Edition (experimental)

Independent development branch for an optional high-quality presentation/upscaling path in Dolphin. The original `master` branch is left untouched.

## Hardware target

Initial target machine: Windows laptop, NVIDIA GeForce RTX 3060 Laptop GPU, AMD Ryzen 7 4800H, 16 GB RAM, 1920x1080 display. These are the user's reported specifications; performance must be measured on the actual machine.

## Current implementation status

- [x] Dedicated branch: `fsr3-frame-generation`.
- [x] First experimental spatial post-processing shader: `FSR_Spatial.glsl` (edge-aware sharpening prototype; not FSR).
- [x] Add a shader-side adaptation of AMD FidelityFX FSR 1 EASU (`FSR1_EASU.glsl`) with AMD's copyright and license notice preserved.
- [x] Add a standalone shader-side adaptation of AMD FSR 1 RCAS (`FSR1_RCAS.glsl`) with the AMD license notice preserved. It is not yet chained automatically after EASU or visually validated.
- [ ] Integrate EASU → RCAS as a true two-pass path and validate output against AMD reference behavior.
- [ ] Evaluate native FidelityFX SDK integration for future temporal FSR 2/3 and backend-level frame generation.
- [ ] Add a dedicated Dolphin settings page and quality/performance presets.
- [ ] Implement and validate FSR 2/3 temporal upscaling only if reliable motion vectors, depth, jitter and frame history can be supplied by the emulator.
- [ ] Frame generation 2x: research and architecture only. Not implemented.
- [ ] D3D12 and Vulkan runtime validation.
- [x] Add a CI GLSL syntax-check harness for EASU, RCAS and the separate sharpening experiment. The validator wrapper now exposes Dolphin's `SampleLocation` helper; the new RCAS check is pending a fresh CI run.
- [x] Windows x64 build and package generation succeeded in GitHub Actions for commit `c3d03f5` (before the RCAS-only additions). A fresh build for the current branch head and in-emulator runtime testing remain pending.

## Important technical distinction

`FSR1_EASU.glsl` adapts AMD's FSR 1 EASU spatial upscaling algorithm and preserves its permissive license notice. It is not the complete FidelityFX SDK integration and has not yet been compiled or visually validated in Dolphin. `FSR_Spatial.glsl` is a separate original sharpening experiment. Neither shader implements FSR 2/3 temporal accumulation or frame generation.

FSR 2/3 temporal upscaling requires motion vectors, depth, jitter metadata and a history pipeline. A post-processing shader that only sees the final color image cannot reconstruct those inputs reliably. FSR 3 frame generation additionally requires a supported swapchain/presentation integration and an explicit UI-composition strategy; Dolphin's current composed final-color path does not yet provide the required per-pixel data or separate UI layer. AMD recommends a stable 60 FPS or higher input for optimal FSR 3.1.7 frame generation (30 FPS is a lower-bound experiment, not the preferred target).

Frame generation is a separate subsystem. Even a successful 2x frame-generation path does not increase emulated CPU/game logic speed: 30 real emulation FPS plus generated intermediate images may display 60 images per second while the game simulation still advances at 30 FPS. Input latency and artifacts must be measured.

## Build on Windows x64

The branch includes `BUILD_FSR_EDITION_WINDOWS.bat`. Run it from the repository root in an **x64 Native Tools Command Prompt for Visual Studio** on Windows, with Git for Windows, MSVC C++ build tools, the Windows SDK, CMake and Ninja installed. It initializes submodules, runs Dolphin's `ninja-release-x64` CMake workflow, writes `build_fsr_edition.log`, and opens the output folder if `Dolphin.exe` is found. The helper script has not been run locally on the target laptop. GitHub Actions did successfully compile and package the Windows x64 build for commit `c3d03f5`; the current RCAS additions still need a fresh build run.

## Try the current shader

1. Build this branch using Dolphin's normal Windows build instructions.
2. Copy `Data/Sys/Shaders/FSR1_EASU.glsl`, `Data/Sys/Shaders/FSR1_RCAS.glsl` and/or `Data/Sys/Shaders/FSR_Spatial.glsl` into the build's system shader directory (or the user shader directory).
3. Open Graphics > Enhancements > Post-Processing Effect and select `FSR1_EASU` to try the EASU prototype, `FSR1_RCAS` for the RCAS sharpening pass, or `FSR_Spatial` for the separate adjustable sharpening experiment.
4. Compare against post-processing off at the same internal and output resolutions. EASU and RCAS are standalone selections at this stage: the current Dolphin UI does not chain RCAS after EASU automatically. Treat both as unvalidated until they are compiled and tested inside Dolphin.

The shaders are prototypes. The post-processing loader discovers `.glsl` files from Dolphin's shader directories; place the files in the actual system shader directory used by the build (`Data/Sys/Shaders` in the source tree or the equivalent installed `Sys/Shaders` directory). If it is not listed, check the Dolphin log for shader discovery or compilation errors. These shaders are not standalone executables. A Windows build exists from the earlier branch revision, but the latest RCAS shader has not yet been confirmed in a fresh package or tested in Dolphin.

## Safe performance baseline for the target laptop

- Backend: test Direct3D 12 and Vulkan separately; keep the one with fewer frame-time spikes and correct graphics for the game.
- Internal resolution: begin at 2x or 3x native, then test 4x only if GPU headroom remains.
- V-Sync: test both states; do not use frame generation to hide emulation-speed drops.
- Shader compilation: enable the shader cache and avoid changing several settings between comparisons.
- Record real emulation speed, frame time, GPU utilization, VRAM use and temperatures.

The requested 5K/8K/above-8K output modes are experimental stress tests, not performance promises. A 1080p panel cannot display their additional output detail directly, and very high EFB scales can exhaust VRAM or cause severe slowdown.

## Licensing

Dolphin is GPL-2.0-or-later. This branch must preserve Dolphin's licensing and include the required license notices for any third-party FidelityFX code or SDK added later. `FSR1_EASU.glsl` and `FSR1_RCAS.glsl` are shader-side adaptations of AMD FSR 1 source under the permissive license reproduced in each file. `FSR_Spatial.glsl` is original experimental code. The full AMD FidelityFX SDK has not been vendored into this branch.

## Experimental internal resolution above 8K

This branch raises the selectable maximum EFB/internal scale to 16x and labels the 16x entry as **10K (experimental)** in Graphics > Enhancements. At the GameCube/Wii base EFB size of 640x528, 16x corresponds to 10240x8448 internal pixels. This is an internal rendering stress test; it does not change a 1920x1080 monitor into a 10K display and the final image is still presented at the window/output size. Dolphin also clamps the effective EFB scale to the backend's maximum texture dimension, so the actual allocated size can be lower than the menu label.

**Warning:** 16x can consume several gigabytes across color/depth buffers, copies and caches, especially in games with multiple render targets. On an RTX 3060 Laptop GPU, start at 2x or 3x. Use 16x only as a deliberate stress test, monitor VRAM, and lower the scale immediately if allocation fails, the game slows severely, or the driver resets. The 10K option is not a recommended everyday setting.
