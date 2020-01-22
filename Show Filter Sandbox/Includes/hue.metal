//
//  hue.metal
//  MavFarm
//
//  Created by Connor Bell on 2018-12-26.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 hue(float3 c, float s)
{
    const float3 dir = float3(0.55735);
    const float pi2 = 6.2832;
    float3 p = dir*dot(dir,c);
    float3 u = c-p;
    float3 v = cross(dir,u);
    
    float spi2 = s*pi2;
    c = u*cos(spi2) + v*sin(spi2) + p;
    
    return c;
}
