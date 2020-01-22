//
//  blending.metal
//  MavFarm
//
//  Created by Connor Bell on 2018-12-17.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 blendSoftLight(float3 base, float3 blend) {
    float3 s = step(0.5,blend);
    return s * (sqrt(base)*(2.0*blend-1.0)+2.0*base*(1.0-blend)) + (1.-s)*(2.*base*blend+base*base*(1.0-2.0*blend));
}

float3 overlay(float3 base, float3 overlay) {
    const float3 W = float3(0.2125, 0.7154, 0.0721);
    float l = dot(base, W);
    
    float3 s = step(0.5,l);
    return (s * (2. * overlay * base )) + ((1.-s) * (1. - (1. - (2. * (overlay - 0.5)))*(1. - base)));
}
