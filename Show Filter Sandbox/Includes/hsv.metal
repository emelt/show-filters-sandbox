//
//  hsv.metal
//  MavFarm
//
//  Created by Connor Bell on 2018-12-15.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 rgb2hsv(float3 c)
{
    const float4 K = float4(0.0, -0.33333, 0.66667, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c)
{
    const float4 K = float4(1.0, 0.66667, 0.33333, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


