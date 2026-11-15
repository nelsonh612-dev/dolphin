#!/usr/bin/env python3
"""Compile-check Dolphin post-processing shaders the way Dolphin assembles them.

Unlike a hand-written wrapper, this script:
  * parses the shader's [configuration] block with the same rules as
    PostProcessingConfiguration::LoadOptions (Source/Core/VideoCommon/PostProcessing.cpp),
  * emits the option uniforms exactly like PostProcessing::GetUniformBufferHeader(true),
  * prepends the real helper header from PostProcessing::GetHeader and the Vulkan
    SHADER_HEADER (D3D12 compiles the same GLSL to SPIR-V through glslang),
  * rejects configuration problems that would generate invalid GLSL, such as an
    option without OptionName (this produced "int ;" -> "unexpected SEMICOLON,
    expecting IDENTIFIER" in FSR1_RCAS).

It still does not replace running a game in Dolphin on D3D12/Vulkan/OpenGL.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
VALID_TYPES = {"OptionBool": "bool", "OptionRangeFloat": "float", "OptionRangeInteger": "int"}

BUILTIN_UNIFORMS = """UBO_BINDING(std140, 1) uniform PSBlock {
  float4 resolution;
  float4 target_resolution;
  float4 window_resolution;
  int2 stereo_views;
  float4 src_rect;
  int src_layer;
  uint time;
  int graphics_api;
  int intermediary_buffer;
  int resampling_method;
  int correct_color_space;
  int game_color_space;
  int correct_gamma;
  float game_gamma;
  int sdr_display_gamma_sRGB;
  float sdr_display_custom_gamma;
  int linear_space_output;
  int hdr_output;
  float hdr_paper_white_nits;
  float hdr_sdr_white_nits;
"""


def raw_string(path: Path, pattern: str) -> str:
    match = re.search(pattern, path.read_text(encoding="utf-8"), re.S)
    if not match:
        raise SystemExit(f"Could not extract shader header from {path}")
    return match.group(1)


def parse_options(source: str, shader: Path) -> tuple[dict[str, tuple[str, int]], list[str]]:
    """Mirror LoadOptions. Returns (options, problems)."""
    problems: list[str] = []
    options: dict[str, tuple[str, int]] = {}
    start, end = source.find("[configuration]"), source.find("[/configuration]")
    if start == -1 or end == -1:
        return options, problems

    blocks: list[dict] = []
    current = None
    for line in source[start + len("[configuration]"):end].splitlines():
        line = line.rstrip("\r")
        if not line:
            continue
        if line.startswith("[/"):
            problems.append(f"{shader.name}: closing tag '{line}' is not part of Dolphin's "
                            "post-processing format; remove it")
            current = None
            continue
        if line.startswith("["):
            close = line.find("]")
            if close != -1:
                current = {"type": line[1:close], "opts": {}}
                blocks.append(current)
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            current["opts"][key.strip()] = value.strip()

    for block in blocks:
        name = block["opts"].get("OptionName", "")
        if block["type"] not in VALID_TYPES:
            problems.append(f"{shader.name}: unknown option section [{block['type']}]")
            continue
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            problems.append(f"{shader.name}: [{block['type']}] has missing/invalid "
                            f"OptionName '{name}'")
            continue
        kind = VALID_TYPES[block["type"]]
        count = 1
        if kind != "bool":
            count = min(4, len(block["opts"].get("DefaultValue", "0").split(",")))
        options[name] = (kind, count)
    return options, problems


def build_source(source: str, options: dict[str, tuple[str, int]], vk_header: str,
                 helpers: str) -> str:
    ubo = BUILTIN_UNIFORMS + "\n"
    pad = 1
    for name in sorted(options):  # std::map iteration order
        kind, count = options[name]
        base = "int" if kind in ("bool", "int") else "float"
        ubo += f"  {base}{'' if count == 1 else count} {name};\n"
        for _ in range(count, 4):
            ubo += f"  {base} ubo_align_{pad}_;\n"
            pad += 1
    ubo += "};\n\n"
    header = (ubo + "SAMPLER_BINDING(0) uniform sampler2DArray samp0;\n"
              "SAMPLER_BINDING(1) uniform sampler2DArray samp1;\n"
              "VARYING_LOCATION(0) in VertexData {\n  float3 v_tex0;\n};\n"
              "FRAGMENT_OUTPUT_LOCATION(0) out float4 ocol0;\n" + helpers)
    return vk_header + header + source


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validator", default="glslangValidator")
    parser.add_argument("shaders", nargs="+", type=Path)
    args = parser.parse_args()

    vk_header = raw_string(REPO / "Source/Core/VideoBackends/Vulkan/ShaderCompiler.cpp",
                           r'SHADER_HEADER\[\] = R"\((.*?)\)";')
    helpers = raw_string(REPO / "Source/Core/VideoCommon/PostProcessing.cpp",
                         r'std::string PostProcessing::GetHeader.*?ss << R"\((.*?)\)";')

    failed = False
    for shader in args.shaders:
        if not shader.is_file():
            parser.error(f"Shader not found: {shader}")
        source = shader.read_text(encoding="utf-8")
        options, problems = parse_options(source, shader)
        print(f"Checking {shader} (options: {', '.join(options) or 'none'})...")
        for name in re.findall(r"GetOption\(\s*(\w+)\s*\)|OptionEnabled\(\s*(\w+)\s*\)", source):
            used = next(n for n in name if n)
            builtins = set(re.findall(r"\b(\w+);", BUILTIN_UNIFORMS))
            if used not in options and used not in builtins:
                problems.append(f"{shader.name}: GetOption({used}) has no matching OptionName")
        for problem in problems:
            print(f"  ERROR: {problem}")
        failed |= bool(problems)

        full = build_source(source, options, vk_header, helpers)
        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "shader.frag"
            input_path.write_text(full, encoding="utf-8")
            result = subprocess.run(
                [args.validator, "-V", "--target-env", "vulkan1.0", "-S", "frag",
                 "-o", str(Path(temp_dir) / "shader.spv"), str(input_path)],
                capture_output=True, text=True)
            if result.returncode != 0:
                failed = True
                output = result.stdout + result.stderr
                print(output)
                lines = full.splitlines()
                for match in re.finditer(r"ERROR: \S+?:(\d+):", output):
                    number = int(match.group(1))
                    if 0 < number <= len(lines):
                        print(f"  generated line {number}: {lines[number - 1]!r}")

    if failed:
        print("Shader validation FAILED.")
        return 1
    print("All shader checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
