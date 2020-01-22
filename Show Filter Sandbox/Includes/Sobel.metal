//
//  Sobel.metal
//  MavFarm
//
//  Created by Connor Bell on 2018-12-14.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float fintensity(float4 col, float scale)
{
    col = floor(col * 2.) / 2.;
    return dot(col, col)*scale;
}

float sobelSample(texture2d<float, access::read> inTexture, uint2 p, int2 texel, float scale)
{
    float topLeft       = fintensity(inTexture.read(p + (uint2)int2(-texel.x, texel.y)), scale);
    float topCenter     = fintensity(inTexture.read(p + (uint2)int2(0., texel.y)), scale);
    float topRight      = fintensity(inTexture.read(p + (uint2)int2(texel.x, texel.y)), scale);
    float centerLeft    = fintensity(inTexture.read(p + (uint2)int2(-texel.x, 0.)), scale);
    float centerRight   = fintensity(inTexture.read(p + (uint2)int2(-texel.x, 0.)), scale);
    float bottomLeft    = fintensity(inTexture.read(p + (uint2)int2(-texel.x, -texel.y)), scale);
    float bottomCenter  = fintensity(inTexture.read(p + (uint2)int2(0., -texel.y)), scale);
    float bottomRight   = fintensity(inTexture.read(p + (uint2)int2(texel.x, -texel.y)), scale);
    
    float x = topLeft + centerLeft * 2.0 + bottomCenter - topRight - centerRight * 2.0 - bottomRight;
    float y = bottomLeft + bottomCenter * 2.0 + bottomRight - topLeft - 2.0 * topCenter - topRight;
    
    float2 v = float2(x, y);
    return dot(v, v);
}

