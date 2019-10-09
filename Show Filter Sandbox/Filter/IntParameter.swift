//
//  IntParameter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-16.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

class IntParameter : Parameter {
    
    public var defaultValue : Int
    public var currentValue : Int = 0
    
    init(idx: Int, name: String, defaultVal: Int)
    {
        self.defaultValue = defaultVal
        self.currentValue = defaultVal
        
        super.init()
        self.targetIndex = idx
        self.name = name
    }
}
