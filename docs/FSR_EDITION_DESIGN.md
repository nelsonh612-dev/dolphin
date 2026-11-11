# FSR Edition engineering notes

## Architecture decisions

### Spatial stage (first milestone)
Use Dolphin's existing `VideoCommon::PostProcessing` pipeline for a low-risk prototype. This stage is backend-agnostic at the shader interface, so it is a practical first point for testing on D3D12 and Vulkan. It operates on the presented color image and therefore cannot access per-object motion vectors or reliably infer depth.

### True FidelityFX integration (next milestone)
Evaluate the official AMD FidelityFX SDK 2.x (the current AMD SDK family that includes FSR 2/3) and its licensing/build requirements. AMD documents native Direct3D 12 and Vulkan support. FSR 1 is spatial (EASU upscaling + RCAS sharpening) and is the simpler first production integration. FSR 2/3 need temporal inputs and a persistent history path; the emulator must produce correct motion vectors, depth and jitter metadata for each frame. Do not advertise FSR 2/3 until these inputs and disocclusion handling are implemented and tested.

### Frame generation (separate milestone)
Do not implement a fake 2x toggle. First map the present/swapchain lifecycle for D3D12 and Vulkan, then prototype an opt-in frame interpolation path with explicit generated-vs-real frame metrics. It must handle camera cuts, UI, stereo, pause/menus, variable frame pacing, input latency and shutdown/reinitialization. If reliable motion vectors are unavailable, any optical-flow fallback must be clearly marked experimental and evaluated for artifacts.

## Required acceptance tests

- Correctness: no broken UI, missing layers, ghosting, flicker, black frames or shader compile failures.
- Timing: measure emulation speed separately from displayed/generated presentation rate.
- Performance: capture frame-time percentiles, GPU/CPU load, VRAM and temperature.
- Backends: test D3D12 and Vulkan independently on the target RTX 3060 laptop.
- Regression: verify the unmodified default post-processing path still works when the new effect is disabled.
- Portability: shader and settings must fail gracefully on unsupported backends.

## Current blocker

The current branch has only a shader prototype and documentation. No C++ frame-generation implementation, FSR SDK integration, custom settings page, Windows binary, or runtime validation is claimed.
