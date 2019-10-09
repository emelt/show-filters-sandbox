//
//  Parameter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-02.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

class FloatParameter : Parameter {

    public var defaultValue : Float
    public var currentValue : Float = 0.0
    public var range : (Float, Float)?

    init(idx: Int, name: String, defaultVal: Float, range: (Float, Float)?)
    {
        self.defaultValue = defaultVal
        self.range = range
        
        super.init()
        
        self.targetIndex = idx
        self.name = name
    }
}
