//
//  Kernel.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-04.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import MetalKit

class Kernel : MPSUnaryImageKernel {
    
    private var computePipelineState: MTLComputePipelineState?

    override init(device: MTLDevice)
    {
        super.init(device: device)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(device: MTLDevice, name: String)
    {
        let bundle = Bundle(for: MetalView.self)
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! device.makeLibrary(filepath: url!.path)
        let computeFunction = library.makeFunction(name: name)!
        
        do {
            self.computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        }
        catch {
            fatalError("Impossible to create a kernel. \(error)")
        }
        super.init(device: device)
    }
    
    func encode(commandBuffer: MTLCommandBuffer,
                sourceTexture: MTLTexture,
                destinationTexture: MTLTexture,
                updateUniformsCallback: ((MTLComputeCommandEncoder) -> Void))
    {
        if let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeCommandEncoder.setComputePipelineState(computePipelineState!)
            
            updateUniformsCallback(computeCommandEncoder)
            
            computeCommandEncoder.dispatchThreadgroups(computePipelineState: computePipelineState!, width: destinationTexture.width, height: destinationTexture.height)
            computeCommandEncoder.endEncoding()
        }
    }
}
