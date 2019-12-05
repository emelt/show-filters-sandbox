//
//  Vec2Parameter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-11-03.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import simd
import UIKit

class Vec2Parameter : Parameter {
    
    public var defaultValue : vector_float2
    public var currentValue : vector_float2
    
    public var bounds : vector_float4 // xy: x range low - high,  zw: y range low - high
    
    init(idx: Int, name: String, defaultVal: vector_float2, bounds:vector_float4 = vector_float4(-1.0,1.0,-1.0,1.0))
    {
        self.defaultValue = defaultVal
        self.currentValue = defaultVal
        
        self.bounds = bounds
        
        super.init()
        
        self.targetIndex = idx
        self.name = name
    }
    
    func updateWithPoint(v: CGPoint)
    {
        self.currentValue = vector2(bounds.x + Float(bounds.y - bounds.x) * Float(v.x),
                                    bounds.z + Float(bounds.w - bounds.z) * Float(v.y))
    }
}
