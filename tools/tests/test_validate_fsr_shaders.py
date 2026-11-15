#!/usr/bin/env python3
"""Regression tests for Dolphin's FSR post-processing configuration validator."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import validate_fsr_shaders as validator  # noqa: E402


class ShaderOptionParserTests(unittest.TestCase):
    def test_valid_float_option_generates_a_named_uniform(self) -> None:
        source = """
[configuration]
[OptionRangeFloat]
GUIName = RCAS Sharpness
OptionName = sharpness_stops
MinValue = 0.0
MaxValue = 4.0
DefaultValue = 1.0
StepAmount = 0.25
[/configuration]
"""
        options, problems = validator.parse_options(source, Path("valid.glsl"))

        self.assertEqual(problems, [])
        self.assertEqual(options, {"sharpness_stops": ("float", 1)})
        generated = validator.build_source(source, options, "", "")
        self.assertIn("float sharpness_stops;", generated)
        self.assertNotRegex(generated, r"(?m)^\s*(?:int|float)\s*;")

    def test_legacy_option_closing_tag_is_rejected_without_empty_uniform(self) -> None:
        source = """
[configuration]
[OptionRangeFloat]
GUIName = RCAS Sharpness
OptionName = sharpness_stops
MinValue = 0.0
MaxValue = 4.0
DefaultValue = 1.0
StepAmount = 0.25
[/OptionRangeFloat]
[/configuration]
"""
        options, problems = validator.parse_options(source, Path("legacy.glsl"))

        self.assertEqual(options, {"sharpness_stops": ("float", 1)})
        self.assertTrue(any("closing tag" in problem for problem in problems))
        generated = validator.build_source(source, options, "", "")
        self.assertIn("float sharpness_stops;", generated)
        self.assertNotRegex(generated, r"(?m)^\s*(?:int|float)\s*;")

    def test_unknown_type_and_missing_option_name_are_rejected(self) -> None:
        source = """
[configuration]
[OptionMystery]
GUIName = Unknown
OptionName = mystery
[OptionRangeFloat]
GUIName = Missing name
DefaultValue = 1.0
[/configuration]
"""
        options, problems = validator.parse_options(source, Path("invalid.glsl"))

        self.assertEqual(options, {})
        self.assertEqual(len(problems), 2)
        generated = validator.build_source(source, options, "", "")
        self.assertNotRegex(generated, r"(?m)^\s*(?:int|float)\s*;")

    def test_vector_option_uses_matching_uniform_width(self) -> None:
        source = """
[configuration]
[OptionRangeFloat]
GUIName = RGB
OptionName = rgb_gain
MinValue = 0.0, 0.0, 0.0
MaxValue = 2.0, 2.0, 2.0
DefaultValue = 1.0, 1.0, 1.0
StepAmount = 0.1, 0.1, 0.1
[/configuration]
"""
        options, problems = validator.parse_options(source, Path("vector.glsl"))

        self.assertEqual(problems, [])
        self.assertEqual(options, {"rgb_gain": ("float", 3)})
        generated = validator.build_source(source, options, "", "")
        self.assertIn("float3 rgb_gain;", generated)

    def test_shipped_fsr_shader_configuration_blocks_are_valid(self) -> None:
        shader_dir = TOOLS_DIR.parent / "Data" / "Sys" / "Shaders"
        for shader_name in ("FSR1_EASU.glsl", "FSR_Spatial.glsl", "FSR1_RCAS.glsl"):
            with self.subTest(shader=shader_name):
                shader = shader_dir / shader_name
                source = shader.read_text(encoding="utf-8")
                _, problems = validator.parse_options(source, shader)
                self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
