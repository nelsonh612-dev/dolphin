// Dolphin FSR Edition - experimental spatial sharpening filter
// Copyright (C) 2026
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Original spatial post-processing experiment. This is NOT AMD FidelityFX
// Super Resolution (FSR 1/2/3), does not perform temporal reconstruction,
// and does not generate intermediate frames.
//
// The filter operates on Dolphin's final color image. It can modestly improve
// perceived edge definition, but cannot recreate missing geometry or detail.

[configuration]
[OptionRangeFloat]
GUIName = Sharpening Strength
OptionName = sharpness
MinValue = 0.0
MaxValue = 1.0
DefaultValue = 0.35
StepAmount = 0.05
[/OptionRangeFloat]
[/configuration]

float LumaFSR(float3 color)
{
  return dot(color, float3(0.299, 0.587, 0.114));
}

float4 mainFSRSpatial(float2 uv)
{
  float2 inv_resolution = GetInvResolution();

  float3 center = SampleLocation(uv).rgb;
  float3 north = SampleLocation(uv + float2(0.0, -1.0) * inv_resolution).rgb;
  float3 south = SampleLocation(uv + float2(0.0, 1.0) * inv_resolution).rgb;
  float3 east = SampleLocation(uv + float2(1.0, 0.0) * inv_resolution).rgb;
  float3 west = SampleLocation(uv + float2(-1.0, 0.0) * inv_resolution).rgb;

  float3 average = (north + south + east + west) * 0.25;
  float local_contrast = abs(LumaFSR(center - average));

  // Reduce sharpening in high-contrast areas to limit halos and ringing.
  float strength = GetOption(sharpness) / (1.0 + local_contrast * 4.0);
  float3 sharpened = center + (center - average) * strength;

  // Clamp to the local 5-tap range to avoid overshoot.
  float3 local_min = min(center, min(min(north, south), min(east, west)));
  float3 local_max = max(center, max(max(north, south), max(east, west)));
  sharpened = clamp(sharpened, local_min, local_max);

  return float4(max(sharpened, float3(0.0, 0.0, 0.0)), 1.0);
}

void main()
{
  SetOutput(mainFSRSpatial(GetCoordinates()));
}
