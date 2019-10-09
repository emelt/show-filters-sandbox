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
    
    var filters : [Filter] = []
    
    init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()!

        self.commandQueue = metalDevice.makeCommandQueue()!
        self.commandQueue.label = "com.mavfarm.videoProcessor.commandQueue"
        
        self.passthroughKernel = PassthroughKernel(device: self.metalDevice)
        self.filters = [self.passthroughKernel]
        
    }
}
