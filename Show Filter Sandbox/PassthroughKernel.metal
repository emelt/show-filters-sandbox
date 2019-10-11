//
//  Passthrough.metal
//  PlayerWithReader
//
//  Created by Geppy Parziale on 3/20/17.
//  Copyright © 2017 iNVASIVECODE Inc. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void passthroughKernel(texture2d<half, access::sample> inTexture [[ texture(0) ]],
							  texture2d<half, access::write> outTexture [[ texture(1) ]],
							  uint2 gid [[ thread_position_in_grid ]])
{
	if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) { return; }

	const half4 colorAtPixel = 1.-inTexture.read(gid);
	outTexture.write(colorAtPixel, gid);
}

