//
//  Passthrough.metal
//  MavFarm
//
//  Created by Connor Bell on 2019-10-07.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void InvertKernel(texture2d<half, access::sample> inTexture [[ texture(0) ]],
                         texture2d<half, access::write> outTexture [[ texture(1) ]],
                         uint2 gid [[ thread_position_in_grid ]])
{
	if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) { return; }

	half4 colorAtPixel = 1.-inTexture.read(gid);
	outTexture.write(colorAtPixel, gid);
}

