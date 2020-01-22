//
//  Sobel.h
//  MavFarm
//
//  Created by Connor Bell on 2018-12-14.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

#ifndef Sobel_h
#define Sobel_h

float sobelSample(texture2d<float, access::read> inTexture, uint2 p, int2 texel, float scale);

#endif /* Sobel_h */
