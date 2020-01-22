//
//  NoiseFuncs.metal
//  MavFarm
//
//  Created by Connor Bell on 2018-12-13.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#include <metal_stdlib>

#include "NoiseFuncs.h"

using namespace metal;

float random(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise1d(float p) {
    float fl = floor(p);
    float fc = fract(p);
    float u = smoothstep(0.,1.,fc);
    return mix(random(fl), random(fl + 1.0), u);
}

float noise2dTex(texture2d<float, access::sample> tex, sampler colorSampler, float2 pos) {
    return tex.sample(colorSampler, pos).r;
}

float fbm(float pos) {
    float n = 0.;
    float scale = 0.6666;
    
    for (int i = 0; i < 4; i += 1)
    {
        n += noise1d(pos) * scale;
        scale *= 0.5;
        pos *= 2.;
    }
    
    return n;
}

float fbm(texture2d<float, access::sample> tex, sampler colorSampler, float2 pos) {
    float n = 0.;
    float scale = 0.6666;
        
    for (int i = 0; i < 4; i += 1)
    {
        n += noise2dTex(tex, colorSampler, pos) * scale;
        scale *= 0.5;
        pos *= 2.;
    }
    
    return n;
}


float noise2dTex(texture2d<float, access::read> tex, float2 pos) {
    return tex.read(uint2(pos)).r;
}

float fbm(texture2d<float, access::read> tex, float2 pos) {
    float n = 0.;
    float scale = 0.6666;
    float2 texSize = float2(tex.get_width(), tex.get_height());
    
    for (int i = 0; i < 4; i += 1)
    {
        float2 noiseGID = abs(pos * texSize);
        
        n += noise2dTex(tex, noiseGID) * scale;
        scale *= 0.5;
        pos *= 2.;
    }
    
    return n;
}
