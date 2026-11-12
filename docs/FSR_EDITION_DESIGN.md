# FSR Edition engineering notes

## Architecture decisions

### Spatial stage (first milestone)
Use Dolphin's existing `VideoCommon::PostProcessing` pipeline for a low-risk prototype. This stage is backend-agnostic at the shader interface, so it is a practical first point for testing on D3D12 and Vulkan. It operates on the presented color image and therefore cannot access per-object motion vectors or reliably infer depth.

### True FidelityFX integration (next milestone)
Evaluate the official AMD FidelityFX SDK 2.x (the current AMD SDK family that includes FSR 2/3) and its licensing/build requirements. AMD documents native Direct3D 12 and Vulkan support. FSR 1 is spatial (EASU upscaling + RCAS sharpening) and is the simpler first production integration. FSR 2/3 need temporal inputs and a persistent history path; the emulator must produce correct motion vectors, depth and jitter metadata for each frame. Do not advertise FSR 2/3 until these inputs and disocclusion handling are implemented and tested.

### Frame generation (separate milestone)
Do not implement a fake 2x toggle. First map the present/swapchain lifecycle for D3D12 and Vulkan, then prototype an opt-in frame interpolation path with explicit generated-vs-real frame metrics. It must handle camera cuts, UI, stereo, pause/menus, variable frame pacing, input latency and shutdown/reinitialization. If reliable motion vectors are unavailable, any optical-flow fallback must be clearly marked experimental and evaluated for artifacts.

## Dolphin integration points confirmed in source

- `VideoCommon::Presenter` owns the presentation path and the `PostProcessing` instance. Its `RenderXFBToScreen` method draws the selected XFB to the screen and performs post-processing.
- `VideoCommon::PostProcessing::BlitFromTexture` receives a source color texture and source/destination rectangles. This is a suitable location for a spatial post-process, but it is not a source of per-object motion vectors or depth history.
- `AbstractGfx` is Dolphin's backend abstraction and exposes texture/framebuffer creation, compute dispatch, `BindBackbuffer` and `PresentBackbuffer`. The D3D12 backend implements these operations and owns a swapchain with per-buffer texture/framebuffer resources.
- Therefore, a true FSR 2/3 path must extend the frame data/resource flow upstream of the final color-only post-process. A frame-generation path must coordinate with each backend's swapchain and GPU synchronization; a shader-only edit in `PostProcessing.cpp` cannot provide correct generated frames.

## Required acceptance tests

- Correctness: no broken UI, missing layers, ghosting, flicker, black frames or shader compile failures.
- Timing: measure emulation speed separately from displayed/generated presentation rate.
- Performance: capture frame-time percentiles, GPU/CPU load, VRAM and temperature.
- Backends: test D3D12 and Vulkan independently on the target RTX 3060 laptop.
- Regression: verify the unmodified default post-processing path still works when the new effect is disabled.
- Portability: shader and settings must fail gracefully on unsupported backends.

## Current blocker

The current branch has only a shader prototype and documentation. No C++ frame-generation implementation, FSR SDK integration, custom settings page, Windows binary, or runtime validation is claimed.

## First FSR implementation increment

The branch now contains `Data/Sys/Shaders/FSR1_EASU.glsl`, a shader-side adaptation of AMD's FSR 1 EASU algorithm. It maps the current post-process source rectangle to the output pixel grid, evaluates the 12-tap edge-adaptive reconstruction kernel, uses point sampling for the taps, and clamps the result to the nearest 2x2 neighborhood to reduce ringing. The AMD copyright and permissive license notice are retained in the shader.

This is a spatial EASU pass, not the complete FidelityFX SDK integration. RCAS is not included yet. The shader must still be compiled and visually validated on Dolphin's D3D12 and Vulkan paths before it is considered usable. The original `FSR_Spatial.glsl` remains as a simpler comparison filter.

## Second FSR 1 implementation increment: RCAS

The branch now contains `Data/Sys/Shaders/FSR1_RCAS.glsl`, a shader-side adaptation of AMD's RCAS filter. It uses the 3x3 cross neighborhood (north, west, center, east, south), computes per-channel neighborhood extrema, solves a bounded negative-lobe weight to avoid clipping, and exposes sharpness in stops (0 = strongest, each +1 halves the strength). The optional noise attenuation path is enabled in this adaptation. The AMD copyright and permissive license notice are retained.

Important pipeline limitation: AMD specifies RCAS as a separate pass after EASU. Dolphin's existing user post-processing selector currently selects one shader, not an ordered chain of arbitrary user shaders. Therefore the new RCAS file is selectable by itself and is not yet an integrated EASU→RCAS pipeline. A future integration must add an explicit intermediate target and run EASU then RCAS without breaking stereo, color correction, HDR, or backend synchronization.

The CI shader harness was extended to include RCAS and to provide Dolphin's `SampleLocation` helper to the shader source. The first CI run previously passed the Windows build but failed its shader harness because that helper was absent from the test wrapper; the wrapper fix and RCAS check are now committed, pending a fresh workflow result.

## Frame-generation feasibility update (AMD FSR 3.1.x)

AMD's current integration guidance makes clear that FSR 3 frame generation is not a final-image shader. It uses an SDK frame-generation context plus a swapchain integration; D3D12 and Vulkan each require the appropriate swapchain/presentation integration. The integration also requires an explicit UI composition strategy. The official options include a separate UI render target, a callback that re-renders UI over generated frames, or a HUD-less/UI comparison path.

Dolphin's current final presentation path receives a composed color texture. This branch has not yet demonstrated reliable per-pixel motion vectors, depth, jitter, or a UI-only layer for arbitrary GameCube/Wii titles. Therefore the current post-process path cannot be promoted to FSR 3 frame generation by simply loading the SDK DLL. The engineering work must first identify where to obtain or reconstruct those inputs and how to preserve game UI, stereo layers, pause/menu transitions, and backend synchronization.

AMD states that FSR 3.1.7 frame generation works without a special GPU-generation requirement, so an NVIDIA RTX 3060 is not automatically excluded by that requirement. However, AMD recommends 60 FPS or higher input for optimal results; it can function from 30 FPS, but frame pacing and artifacts can be worse. This is especially important for the target: frame generation should only be evaluated after the emulator can sustain a stable real 60 FPS in the test scene. Generated presentation FPS must never be reported as real emulation speed.

Official integration references:
- https://gpuopen.com/fidelityfx-super-resolution-3/
- https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/frame-interpolation-swap-chain.md


## EASU → RCAS two-pass integration

The FSR Edition branch now chains the EASU selection through two separate post-processing processors and exposes the RCAS sharpness stops as a Dolphin graphics setting: the EASU stage renders into a size-matched intermediate texture, then a separately compiled RCAS processor samples that texture and writes to the original target. The chain preserves array layers for stereo and falls back to the ordinary EASU pass if intermediate allocation or RCAS initialization fails. This is code-path implementation only; D3D12/Vulkan runtime validation, stereo testing, image comparisons and performance measurements remain outstanding.


## Frame-rate metric semantics

The performance overlay now exposes two distinct measurements: Unique VI FPS counts non-duplicate emulated VI/Immediate frames, while Output FPS counts all presentation callbacks, including duplicate presentations. This is groundwork only; generated FPS must be counted at the actual frame-interpolation submission/presentation point after a real FSR3 frame-generation integration exists. Do not label output FPS as generated FPS.
