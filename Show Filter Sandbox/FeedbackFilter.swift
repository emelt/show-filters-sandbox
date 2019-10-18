//
//  FeedbackFilter.swift
//  MavFarm
//
//  Created by Connor Bell on 10/25/17.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

import MetalKit

class FeedbackFilter : Filter {

    public override var name: String {
        get { return "Feedback" }
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
    
    init(device: MTLDevice) {
        super.init(device: device, name: "FeedbackKernel")
        
        let textures : [String:TextureParameter] =
            [ParameterConstantKeys.SourceTexture:
                TextureParameter(name:ParameterConstantKeys.SourceTexture, texture: nil, targetIndex: 0),
             ParameterConstantKeys.DestinationTexture:
                TextureParameter(name:ParameterConstantKeys.DestinationTexture, texture: nil, targetIndex: 1),
             ParameterConstantKeys.LastTexture:
                TextureParameter(name:ParameterConstantKeys.LastTexture, texture: TextureLoader.shared.blankTexture, targetIndex: 2)]
        
        let floats : [String:FloatParameter] =
            [ParameterConstantKeys.Time:
                FloatParameter(idx: 0, name: ParameterConstantKeys.Time, defaultVal: 0.0, range: (0.0,0.0)),
                "param":
                    FloatParameter(idx: 1, name: "param", defaultVal: 0.0, range: (0.0,0.0))]
        
        self.parameters = FilterParameters(textures: textures, floats: floats )
    }
}
