//
//  TextureParameter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-05.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit

class TextureParameter : Parameter{
    var texture : MTLTexture?
    
    init(name: String, texture: MTLTexture?, targetIndex: Int)
    {
        self.texture = texture
        super.init()
        self.name = name
        self.targetIndex = targetIndex
    }
}
