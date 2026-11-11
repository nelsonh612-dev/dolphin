// Dolphin FSR Edition - experimental edge-adaptive spatial reconstruction
// Copyright (C) 2026
// SPDX-License-Identifier: GPL-2.0-or-later
//
// This is an original, lightweight spatial reconstruction shader inspired by
// edge-adaptive upscaling concepts. It is NOT AMD FidelityFX Super Resolution
// (FSR 1/2/3), does not use temporal data, and does not generate frames.
//
// Dolphin's post-processing stage receives the already-rendered image. This
// shader can improve perceived sharpness when the internal resolution is lower
// than the output resolution, but it cannot recover missing geometry or detail.

float LumaFSR(float3 c)
{
  return dot(c, float3(0.299, 0.587, 0.114));
}

float3 ClampToNeighborhood(float2 uv, float2 px, float3 center)
{
  float3 lo = center;
  float3 hi = center;
  for (int y = -1; y <= 1; ++y)
  {
    for (int x = -1; x <= 1; ++x)
    {
      float3 c = SampleLocation(uv + float2(float(x), float(y)) * px).rgb;
      lo = min(lo, c);
      hi = max(hi, c);
    }
  }
  return clamp(center, lo, hi);
}

float4 FSRSpatial(float2 uv)
{
  float2 px = GetInvResolution();
  float3 c = SampleLocation(uv).rgb;

  // Four axial and four diagonal taps. Weights adapt to local luminance
  // similarity, reducing blur across strong edges.
  float3 sum = c * 2.0;
  float weight_sum = 2.0;
  float center_luma = LumaFSR(c);

  const float offsets[8] = float[8](
    -1.0, 0.0, 1.0, 0.0,
     0.0,-1.0, 0.0, 1.0
  );

  for (int i = 0; i < 4; ++i)
  {
    float2 d = float2(offsets[i * 2], offsets[i * 2 + 1]) * px;
    float3 tap = SampleLocation(uv + d).rgb;
    float edge = abs(LumaFSR(tap) - center_luma);
    float w = 1.0 / (1.0 + edge * 10.0);
    sum += tap * w;
    weight_sum += w;
  }

  float3 local_average = sum / weight_sum;
  float3 low = c - local_average;

  // Conservative sharpening with neighborhood clipping to limit ringing.
  float3 sharpened = c + low * 0.45;
  sharpened = ClampToNeighborhood(uv, px, sharpened);
  return float4(max(sharpened, float3(0.0, 0.0, 0.0)), 1.0);
}

void main()
{
  SetOutput(FSRSpatial(GetCoordinates()));
}
