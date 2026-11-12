// AMD FidelityFX Super Resolution 1 - RCAS shader adaptation for Dolphin
//
// Copyright (c) 2021 Advanced Micro Devices, Inc. All rights reserved.
// Adapted from AMD FidelityFX FSR 1 reference implementation:
// https://github.com/GPUOpen-Effects/FidelityFX-FSR/blob/master/ffx-fsr/ffx_fsr1.h
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// Shader-side adaptation of AMD's spatial RCAS filter. RCAS does not upscale;
// it is intended to run on an already-upscaled image after EASU. Dolphin's
// FSR Edition chains this shader as a separate second pass when FSR1_EASU is selected.
// It remains independently selectable for sharpening-only comparisons.

/*
[configuration]
[OptionRangeFloat]
GUIName = RCAS Sharpness Stops
OptionName = sharpness_stops
MinValue = 0.0
MaxValue = 4.0
DefaultValue = 1.0
StepAmount = 0.25
[/OptionRangeFloat]
[/configuration]
*/

const float FSR1_RCAS_LIMIT = 0.1875;

vec2 FSR1RcasClampUV(vec2 uv)
{
  vec2 half_texel = GetInvResolution() * 0.5;
  return clamp(uv, src_rect.xy + half_texel,
               src_rect.xy + src_rect.zw - half_texel);
}

vec3 FSR1RcasSample(vec2 uv)
{
  return SampleLocation(FSR1RcasClampUV(uv)).rgb;
}

float FSR1RcasSafePositive(float value)
{
  return max(value, 1.0e-6);
}

float FSR1RcasSafeNegative(float value)
{
  return min(value, -1.0e-6);
}

vec4 FSR1Rcas(vec2 uv)
{
  vec2 inv_resolution = GetInvResolution();

  // 3x3 neighborhood: center and the four cardinal neighbors.
  vec3 b = FSR1RcasSample(uv + vec2(0.0, -1.0) * inv_resolution);
  vec3 d = FSR1RcasSample(uv + vec2(-1.0, 0.0) * inv_resolution);
  vec4 center = SampleLocation(FSR1RcasClampUV(uv));
  vec3 e = center.rgb;
  vec3 f = FSR1RcasSample(uv + vec2(1.0, 0.0) * inv_resolution);
  vec3 h = FSR1RcasSample(uv + vec2(0.0, 1.0) * inv_resolution);

  // AMD's luma approximation (twice the conventional weighted luma).
  float bL = b.b * 0.5 + (b.r * 0.5 + b.g);
  float dL = d.b * 0.5 + (d.r * 0.5 + d.g);
  float eL = e.b * 0.5 + (e.r * 0.5 + e.g);
  float fL = f.b * 0.5 + (f.r * 0.5 + f.g);
  float hL = h.b * 0.5 + (h.r * 0.5 + h.g);

  // Noise estimate used by AMD's optional RCAS denoise path.
  float noise = 0.25 * (bL + dL + fL + hL) - eL;
  float luma_max = max(max(max(bL, dL), eL), max(fL, hL));
  float luma_min = min(min(min(bL, dL), eL), min(fL, hL));
  noise = clamp(abs(noise) / max(luma_max - luma_min, 1.0e-6), 0.0, 1.0);
  noise = 1.0 - 0.5 * noise;

  // Per-channel neighborhood extrema.
  vec3 ring_min = min(min(b, d), min(f, h));
  vec3 ring_max = max(max(b, d), max(f, h));

  // Solve the maximum negative-lobe weight that avoids clipping.
  vec3 hit_min = min(ring_min, e) / max(4.0 * ring_max, vec3(1.0e-6));
  vec3 hit_max = (vec3(1.0) - max(ring_max, e)) /
                 min(4.0 * ring_min - vec3(4.0), vec3(-1.0e-6));
  vec3 lobe_candidates = max(-hit_min, hit_max);

  float lobe = max(-FSR1_RCAS_LIMIT,
                   min(max(max(lobe_candidates.r, lobe_candidates.g),
                           lobe_candidates.b), 0.0));

  // AMD expresses sharpness in stops: 0 = maximum, each +1 halves strength.
  float sharpness = exp2(-clamp(GetOption(sharpness_stops), 0.0, 4.0));
  lobe *= sharpness;

  // Noise suppression follows AMD's optional FSR_RCAS_DENOISE behavior.
  lobe *= noise;

  float resolve = 1.0 / max(4.0 * lobe + 1.0, 1.0e-6);
  vec3 result = (lobe * (b + d + f + h) + e) * resolve;

  return vec4(clamp(result, vec3(0.0), vec3(1.0)), center.a);
}

void main()
{
  SetOutput(FSR1Rcas(GetCoordinates()));
}
