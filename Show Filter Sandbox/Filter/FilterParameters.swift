//
//  FilterParameters.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-05.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

class FilterParameters {
    public var textures:[String:TextureParameter] = [:]
    public var floats:[String:FloatParameter] = [:]
    public var ints:[String:IntParameter] = [:]
    
    init ()
    {
        
    }
    
    init(textures:[String:TextureParameter], floats:[String:FloatParameter])
    {
        self.textures = textures
        self.floats = floats
    }
    init(textures:[String:TextureParameter], floats:[String:FloatParameter], ints:[String:IntParameter])
    {
        self.textures = textures
        self.floats = floats
        self.ints = ints
    }
}
