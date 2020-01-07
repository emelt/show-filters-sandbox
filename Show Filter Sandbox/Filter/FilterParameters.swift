//
//  FilterParameters.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-05.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit

class FilterParameters {
    public var textures:[String:TextureParameter] = [:]
    public var floats:[String:FloatParameter] = [:]
    public var ints:[String:IntParameter] = [:]
    public var vector2s:[String:Vec2Parameter] = [:]
    
    public var wantsAudio : Bool = false
    public var audioBuffer : MTLBuffer?
    public var audioBufferIndex : Int?
    
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
    init(textures:[String:TextureParameter], floats:[String:FloatParameter], ints:[String:IntParameter], vector2s:[String:Vec2Parameter])
    {
        self.textures = textures
        self.floats = floats
        self.ints = ints
        self.vector2s = vector2s
    }
    public func createAudioBuffer(bufferIndex: Int) {
        let data = [Float](repeating: Float(), count: 128)

        self.audioBufferIndex = bufferIndex
        self.wantsAudio = true
        self.audioBuffer = TextureLoader.shared.metalDevice.makeBuffer(bytes: data,
                                                                       length:MemoryLayout<Float>.size * data.count,
                                                                       options:[])!
    }
}
