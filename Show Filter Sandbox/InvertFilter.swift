//
//  InvertFilter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-10-07.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

import MetalKit

final class InvertFilter : Filter {

    public override var name: String {
        get { return "Invert" }
        set { }
    }
    public override var filterDescription : String {
        get { return "" }
        set { }
    }
    public override var author: FilterAuthor? {
        get { return FilterAuthor.connorBell }
        set { }
    }
    
    public override var wantsAudio: Bool {
        get { return true }
        set { }
    }
    
    init(device: MTLDevice) {
        super.init(device: device, name: "InvertKernel")
        
        let textures : [String:TextureParameter] =
            [ParameterConstantKeys.SourceTexture:
                TextureParameter(name:ParameterConstantKeys.SourceTexture, texture: nil, targetIndex: 0),
             ParameterConstantKeys.DestinationTexture:
                TextureParameter(name:ParameterConstantKeys.DestinationTexture, texture: nil, targetIndex: 1)]
        
        let vector2s : [String:Vec2Parameter] =
            [ ParameterConstantKeys.UserControlParameter:
                Vec2Parameter(idx:        0,
                              name:       ParameterConstantKeys.UserControlParameter,
                              defaultVal: vector_float2(0.0, 0.0),
                              bounds:     vector_float4(0.0, 1.0, 0.0, 1.0) )
            ]
        self.parameters = FilterParameters(textures: textures, floats: [:], ints:[:], vector2s: vector2s)
        self.createAudioBuffer(bufferIndex: 1)
    }
}
