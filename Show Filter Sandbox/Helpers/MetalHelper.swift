//
//  MetalHelper.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 1/17/19.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit
import MetalPerformanceShaders

class MetalHelper {
    static let shared = MetalHelper()
    
    let metalDevice: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let passthroughKernel: PassthroughKernel
    
    let invertFilter: InvertFilter
    let feedbackFilter: FeedbackFilter
    
    // Create an instance of your filter here
    
    var filters : [Filter] = []
    
    init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()!

        self.commandQueue = metalDevice.makeCommandQueue()!
        self.commandQueue.label = "com.mavfarm.videoProcessor.commandQueue"
        
        self.passthroughKernel = PassthroughKernel(device: self.metalDevice)
        
        self.invertFilter = InvertFilter(device: self.metalDevice)
        self.feedbackFilter = FeedbackFilter(device: self.metalDevice)
        
        self.filters = [self.invertFilter, self.feedbackFilter]
    }
}

extension MTLComputeCommandEncoder {


    /// Dispatches a compute kernel on a 2-dimensional grid.
    ///
    /// - Parameters:
    ///        - width: the first dimension
    ///        - height: the second dimension
    func dispatchThreadgroups(computePipelineState: MTLComputePipelineState, width: Int, height: Int) {

        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let threadGroupSize = MTLSizeMake(w, h, 1)

        let threadGroups = MTLSizeMake((width + threadGroupSize.width  - 1) / threadGroupSize.width,
                                       (height + threadGroupSize.height - 1) / threadGroupSize.height,
                                       1)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }


    /// Dispatches a compute kernel on a 3-dimensional image grid.
    ///
    /// - Parameters:
    ///     - computePipelineState: the compute pipeline state
    ///        - width: the width of the image in pixels
    ///        - height: the height of the image in pixels
    ///        - featureChannels: the number of channels in the image
    ///        - numberOfImages: the number of images in the batch (default is 1)
    func dispatchThreadgroups(computePipelineState: MTLComputePipelineState, width: Int, height: Int, featureChannels: Int = 4, numberOfImages: Int = 1) {

        let slices = ((featureChannels + 3)/4) * numberOfImages

        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let d = 1
        let threadGroupSize = MTLSizeMake(w, h, d)

        let threadGroups = MTLSizeMake( (width  + threadGroupSize.width  - 1) / threadGroupSize.width,
                                        (height + threadGroupSize.height - 1) / threadGroupSize.height,
                                        (slices + threadGroupSize.depth  - 1) / threadGroupSize.depth)

//        printGrid(threadGroups: threadGroups, threadsPerThreadgroup: threadGroupSize)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
}
