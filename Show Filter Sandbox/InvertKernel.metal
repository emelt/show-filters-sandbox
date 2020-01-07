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
                         const device float *audioBuffer [[buffer(1)]],
                         uint2 gid [[ thread_position_in_grid ]])
{
    float2 size = float2(inTexture.get_width(), inTexture.get_height());
	if ((gid.x >= size.x) || (gid.y >= size.y)) { return; }
    float2 uv = float2(gid) / size;
    float audioSamplePos = uv.x * 128.0;
    float audio1 = audioBuffer[(int)(audioSamplePos) % 128];
    float audio2 = audioBuffer[(int)(audioSamplePos + 1) % 128];
    float audio = mix(audio1, audio2, fract(audioSamplePos));
    
	float4 colorAtPixel = inTexture.read(gid);
    colorAtPixel.rgb = mix(colorAtPixel.rgb, audio-colorAtPixel.rgb, float3(param.x, 1., param.y));
	outTexture.write(colorAtPixel, gid);
}

