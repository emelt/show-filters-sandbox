//
//  NoiseFuncs.h
//  MavFarm
//
//  Created by Connor Bell on 2018-12-13.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#ifndef NoiseFuncs_h
#define NoiseFuncs_h

float random(float n);

float noise1d(float p);
float noise2dTex(metal::texture2d<float, metal::access::sample> tex, metal::sampler colorSampler, float2 pos);

float fbm(float pos);
float fbm(metal::texture2d<float, metal::access::sample> tex, metal::sampler colorSampler, float2 pos);

float noise2dTex(metal::texture2d<float, metal::access::read> tex, float2 pos);
float fbm(metal::texture2d<float, metal::access::read> tex, float2 pos);
#endif /* NoiseFuncs_h */
