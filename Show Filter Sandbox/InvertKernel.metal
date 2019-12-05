//
//  Passthrough.metal
//  MavFarm
//
//  Created by Connor Bell on 2019-10-07.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
#include <metal_math>

using namespace metal;

kernel void InvertKernel(texture2d<float, access::sample> inTexture [[ texture(0) ]],
                         texture2d<float, access::write> outTexture [[ texture(1) ]],
                         constant float2 &param [[ buffer(0) ]],
                         uint2 gid [[ thread_position_in_grid ]])
{
	if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) { return; }

	float4 colorAtPixel = inTexture.read(gid);
    colorAtPixel.rgb = mix(colorAtPixel.rgb, 1.-colorAtPixel.rgb, float3(param.x, 1., param.y));
	outTexture.write(colorAtPixel, gid);
}

