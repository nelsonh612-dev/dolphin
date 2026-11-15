// AMD FidelityFX Super Resolution 1 - EASU shader adaptation for Dolphin
//
// Copyright (c) 2021 Advanced Micro Devices, Inc. All rights reserved.
// Adapted from AMD FidelityFX FSR 1 reference source:
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
// This is a shader-side adaptation of AMD's spatial EASU algorithm.
// It is not FSR 2 or FSR 3 and does not perform temporal upscaling or frame generation.

float3 FSR1SamplePoint(float2 uv)
{
  float2 half_texel = GetInvResolution() * 0.5;
  float2 min_uv = src_rect.xy + half_texel;
  float2 max_uv = src_rect.xy + src_rect.zw - half_texel;
  float2 safe_uv = clamp(uv, min_uv, max_uv);
  return texture(samp1, float3(safe_uv, GetLayer())).rgb;
}

void FSR1EasuSet(inout float2 direction, inout float length_value, float2 pp,
                 int quadrant, float lA, float lB, float lC, float lD, float lE)
{
  float weight = 0.0;
  if (quadrant == 0)
    weight = (1.0 - pp.x) * (1.0 - pp.y);
  else if (quadrant == 1)
    weight = pp.x * (1.0 - pp.y);
  else if (quadrant == 2)
    weight = (1.0 - pp.x) * pp.y;
  else
    weight = pp.x * pp.y;

  float dc = lD - lC;
  float cb = lC - lB;
  float length_x = max(abs(dc), abs(cb));
  length_x = 1.0 / max(length_x, 1.0e-8);
  float direction_x = lD - lB;
  direction.x += direction_x * weight;
  length_x = clamp(abs(direction_x) * length_x, 0.0, 1.0);
  length_value += length_x * length_x * weight;

  float ec = lE - lC;
  float ca = lC - lA;
  float length_y = max(abs(ec), abs(ca));
  length_y = 1.0 / max(length_y, 1.0e-8);
  float direction_y = lE - lA;
  direction.y += direction_y * weight;
  length_y = clamp(abs(direction_y) * length_y, 0.0, 1.0);
  length_value += length_y * length_y * weight;
}

void FSR1EasuTap(inout float3 accumulated_color, inout float accumulated_weight,
                 float2 pixel_offset, float2 gradient_direction, float2 anisotropic_length,
                 float negative_lobe_strength, float clipping_point, float3 color)
{
  float2 rotated_offset;
  rotated_offset.x = pixel_offset.x * gradient_direction.x +
                     pixel_offset.y * gradient_direction.y;
  rotated_offset.y = pixel_offset.x * -gradient_direction.y +
                     pixel_offset.y * gradient_direction.x;
  rotated_offset *= anisotropic_length;

  float distance_squared = min(dot(rotated_offset, rotated_offset), clipping_point);
  float weight_b = 0.4 * distance_squared - 1.0;
  float weight_a = negative_lobe_strength * distance_squared - 1.0;
  weight_b *= weight_b;
  weight_a *= weight_a;
  weight_b = (25.0 / 16.0) * weight_b - (25.0 / 16.0 - 1.0);
  float weight = weight_b * weight_a;

  accumulated_color += color * weight;
  accumulated_weight += weight;
}

float4 FSR1Easu(float2 uv)
{
  float2 source_size = GetResolution() * src_rect.zw;
  float2 target_size = GetTargetResolution();

  // EASU is an upscaler. Preserve the normal sample if no enlargement is requested.
  if (target_size.x <= source_size.x && target_size.y <= source_size.y)
    return texture(samp0, float3(uv, GetLayer()));

  // Map the output fragment to the source pixel coordinate system.
  float2 position = ((uv - src_rect.xy) / src_rect.zw) * source_size - 0.5;
  float2 base_position = floor(position);
  float2 pp = position - base_position;
  float2 inv_resolution = GetInvResolution();

  // The 12-tap EASU neighborhood, in source-pixel coordinates.
  float2 p_b = base_position + float2(0.0, -1.0);
  float2 p_c = base_position + float2(1.0, -1.0);
  float2 p_i = base_position + float2(-1.0, 1.0);
  float2 p_j = base_position + float2(0.0, 1.0);
  float2 p_f = base_position;
  float2 p_e = base_position + float2(-1.0, 0.0);
  float2 p_k = base_position + float2(1.0, 1.0);
  float2 p_l = base_position + float2(2.0, 1.0);
  float2 p_h = base_position + float2(2.0, 0.0);
  float2 p_g = base_position + float2(1.0, 0.0);
  float2 p_o = base_position + float2(1.0, 2.0);
  float2 p_n = base_position + float2(0.0, 2.0);

  float2 uv_b = src_rect.xy + (p_b + 0.5) * inv_resolution;
  float2 uv_c = src_rect.xy + (p_c + 0.5) * inv_resolution;
  float2 uv_i = src_rect.xy + (p_i + 0.5) * inv_resolution;
  float2 uv_j = src_rect.xy + (p_j + 0.5) * inv_resolution;
  float2 uv_f = src_rect.xy + (p_f + 0.5) * inv_resolution;
  float2 uv_e = src_rect.xy + (p_e + 0.5) * inv_resolution;
  float2 uv_k = src_rect.xy + (p_k + 0.5) * inv_resolution;
  float2 uv_l = src_rect.xy + (p_l + 0.5) * inv_resolution;
  float2 uv_h = src_rect.xy + (p_h + 0.5) * inv_resolution;
  float2 uv_g = src_rect.xy + (p_g + 0.5) * inv_resolution;
  float2 uv_o = src_rect.xy + (p_o + 0.5) * inv_resolution;
  float2 uv_n = src_rect.xy + (p_n + 0.5) * inv_resolution;

  float3 b = FSR1SamplePoint(uv_b);
  float3 c = FSR1SamplePoint(uv_c);
  float3 i = FSR1SamplePoint(uv_i);
  float3 j = FSR1SamplePoint(uv_j);
  float3 f = FSR1SamplePoint(uv_f);
  float3 e = FSR1SamplePoint(uv_e);
  float3 k = FSR1SamplePoint(uv_k);
  float3 l = FSR1SamplePoint(uv_l);
  float3 h = FSR1SamplePoint(uv_h);
  float3 g = FSR1SamplePoint(uv_g);
  float3 o = FSR1SamplePoint(uv_o);
  float3 n = FSR1SamplePoint(uv_n);

  // Approximate luma, matching the AMD EASU shader's channel weighting.
  float bL = b.b * 0.5 + (b.r * 0.5 + b.g);
  float cL = c.b * 0.5 + (c.r * 0.5 + c.g);
  float iL = i.b * 0.5 + (i.r * 0.5 + i.g);
  float jL = j.b * 0.5 + (j.r * 0.5 + j.g);
  float fL = f.b * 0.5 + (f.r * 0.5 + f.g);
  float eL = e.b * 0.5 + (e.r * 0.5 + e.g);
  float kL = k.b * 0.5 + (k.r * 0.5 + k.g);
  float lL = l.b * 0.5 + (l.r * 0.5 + l.g);
  float hL = h.b * 0.5 + (h.r * 0.5 + h.g);
  float gL = g.b * 0.5 + (g.r * 0.5 + g.g);
  float oL = o.b * 0.5 + (o.r * 0.5 + o.g);
  float nL = n.b * 0.5 + (n.r * 0.5 + n.g);

  float2 direction = float2(0.0, 0.0);
  float edge_length = 0.0;
  FSR1EasuSet(direction, edge_length, pp, 0, bL, eL, fL, gL, jL);
  FSR1EasuSet(direction, edge_length, pp, 1, cL, fL, gL, hL, kL);
  FSR1EasuSet(direction, edge_length, pp, 2, fL, iL, jL, kL, nL);
  FSR1EasuSet(direction, edge_length, pp, 3, gL, jL, kL, lL, oL);

  float direction_squared = dot(direction, direction);
  bool zero_direction = direction_squared < (1.0 / 32768.0);
  float direction_rcp = inversesqrt(max(direction_squared, 1.0e-8));
  direction = zero_direction ? float2(1.0, 0.0) : direction * direction_rcp;

  edge_length *= 0.5;
  edge_length *= edge_length;
  float stretch = dot(direction, direction) /
                  max(max(abs(direction.x), abs(direction.y)), 1.0e-8);
  float2 anisotropic_length =
      float2(1.0 + (stretch - 1.0) * edge_length, 1.0 - 0.5 * edge_length);
  float negative_lobe = 0.5 + (0.21 - 0.5) * edge_length;
  float clipping_point = 1.0 / max(negative_lobe, 1.0e-8);

  float3 min4 = min(min(f, g), min(j, k));
  float3 max4 = max(max(f, g), max(j, k));

  float3 accumulated_color = float3(0.0, 0.0, 0.0);
  float accumulated_weight = 0.0;
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(0.0, -1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, b);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(1.0, -1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, c);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(-1.0, 1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, i);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(0.0, 1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, j);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(0.0, 0.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, f);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(-1.0, 0.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, e);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(1.0, 1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, k);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(2.0, 1.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, l);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(2.0, 0.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, h);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(1.0, 0.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, g);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(1.0, 2.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, o);
  FSR1EasuTap(accumulated_color, accumulated_weight, float2(0.0, 2.0) - pp, direction, anisotropic_length, negative_lobe, clipping_point, n);

  float3 result = accumulated_color / max(accumulated_weight, 1.0e-8);
  result = clamp(result, min4, max4);
  // EASU reconstructs RGB; retain the source alpha channel rather than
  // forcing the intermediate render target to fully opaque.
  float alpha = SampleLocation(uv).a;
  return float4(max(result, float3(0.0, 0.0, 0.0)), alpha);
}

void main()
{
  SetOutput(FSR1Easu(GetCoordinates()));
}
