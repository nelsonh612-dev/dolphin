#!/usr/bin/env python3
"""Compile-check Dolphin post-processing shaders with a minimal GLSL 450 wrapper.

This catches GLSL syntax and type errors in the shader body. It does not replace
Dolphin runtime validation or testing on D3D12/Vulkan.
"""
from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

WRAPPER = """#version 450
#define float2 vec2
#define float3 vec3
#define float4 vec4

layout(set = 0, binding = 0) uniform sampler2DArray samp0;
layout(set = 0, binding = 1) uniform sampler2DArray samp1;
layout(std140, set = 0, binding = 2) uniform PSBlock
{
  vec4 resolution;
  vec4 target_resolution;
  vec4 src_rect;
  float sharpness;
  float sharpness_stops;
};

layout(location = 0) in vec3 v_tex0;
layout(location = 0) out vec4 ocol0;

vec4 SampleLocation(vec2 location) { return texture(samp0, vec3(location, v_tex0.z)); }
vec2 GetResolution() { return resolution.xy; }
vec2 GetInvResolution() { return resolution.zw; }
vec2 GetTargetResolution() { return target_resolution.xy; }
vec2 GetCoordinates() { return v_tex0.xy; }
float GetLayer() { return v_tex0.z; }
#define GetOption(x) (x)
void SetOutput(vec4 color) { ocol0 = color; }

"""

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validator", default="glslangValidator")
    parser.add_argument("shaders", nargs="+", type=Path)
    args = parser.parse_args()

    for shader in args.shaders:
        if not shader.is_file():
            parser.error(f"Shader not found: {shader}")
        source = WRAPPER + shader.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "shader.frag"
            output_path = Path(temp_dir) / "shader.spv"
            input_path.write_text(source, encoding="utf-8")
            command = [
                args.validator,
                "-V",
                "-S", "frag",
                "-o", str(output_path),
                str(input_path),
            ]
            print(f"Checking {shader}...")
            subprocess.run(command, check=True)
    print("All shader syntax checks passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
