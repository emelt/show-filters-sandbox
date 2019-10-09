//
//  PassthroughKernel.swift
//  PlayerWithReader
//
//  Created by Geppy Parziale on 10/25/17.
//  Copyright © 2017 iNVASIVECODE, Inc. All rights reserved.
//

import MetalKit

final class PassthroughKernel: Filter {

    public override var filterDescription : String {
        get { return "" }
        set { }
    }
    public override var author: FilterAuthor? {
        get { return FilterAuthor.connorBell }
        set { }
    }
    
    init(device: MTLDevice) {
        super.init(device: device, name: "passthroughKernel")
        
        let textures : [String:TextureParameter] =
            [ParameterConstantKeys.SourceTexture:
                TextureParameter(name:ParameterConstantKeys.SourceTexture, texture: nil, targetIndex: 0),
             ParameterConstantKeys.DestinationTexture:
                TextureParameter(name:ParameterConstantKeys.DestinationTexture, texture: nil, targetIndex: 1)]
        
        self.parameters = FilterParameters(textures: textures, floats: [:] )
    }
}
