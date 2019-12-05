//
//  FeedbackKernel.metal
//  MavFarm
//
//  Created by Connor Bell on 2019-10-07.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

kernel void FeedbackKernel(texture2d<half, access::sample> inTexture [[ texture(0) ]],
                           texture2d<half, access::write> outTexture [[ texture(1) ]],
                           texture2d<half, access::sample> lastTexture [[ texture(2) ]],
                           device const float &time [[ buffer(0) ]],
                           constant float2 &param [[ buffer(1) ]],
                           uint2 gid [[ thread_position_in_grid ]])
{
	if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) { return; }

	half4 colorAtPixel = inTexture.read(gid);
    half4 lastColorAtPixel = lastTexture.read(gid);
    
    lastColorAtPixel.rgb *= (sin(half3(1.33, 3.66, 7.) * lastColorAtPixel.rgb + param.x) * 0.5 + 0.5);
    
    outTexture.write(colorAtPixel + lastColorAtPixel * param.y, gid);
}

