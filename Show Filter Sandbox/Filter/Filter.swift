//
//  Filter.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-08-30.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import MetalKit

protocol FilterDelegate {
    func filterDidRequestLastTexture(filter: Filter) -> MTLTexture
}

class Filter : NSObject {
    
    public var name : String = ""
    public var filterDescription : String = ""
    public var author : FilterAuthor?
    public var parameters : FilterParameters = FilterParameters()
    public var image : UIImage? {
        let adjustedName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return UIImage(named: adjustedName)
    }
    
    public var wantsAudio : Bool {
        get {
            return self.parameters.wantsAudio
        }
    }
    
    public var delegate : FilterDelegate?
    
    public var isNoFilter: Bool {
        return self.isKind(of: PassthroughKernel.self)
    }
    
    #if !targetEnvironment(simulator)
    private var kernel : Kernel
    #endif
    
    // To be used for allocating resources when the filter starts and finishes being shown
    public func start() { }
    
    public func stop() { }
    
    public func preRender(commandBuffer: MTLCommandBuffer, _width:Int, _height:Int) {}
    public func postRender() {}
    
    init(device: MTLDevice, name: String)
    {
        #if !targetEnvironment(simulator)
        kernel = Kernel(device: device, name: name)
        #endif
        super.init()
        let localizedKey = "filter_description_" + (displayTitle ?? "")
        filterDescription = Localized(localizedKey)
    }
    
    func updateUniforms(encoder: MTLComputeCommandEncoder, sourceTexture: MTLTexture, destinationTexture: MTLTexture, time: Float)
    {
        for (key,param) in parameters.textures {
            switch key {
                case ParameterConstantKeys.SourceTexture:
                    param.texture = sourceTexture
                    encoder.setTexture(sourceTexture, index: param.targetIndex)
                case ParameterConstantKeys.DestinationTexture:
                    param.texture = destinationTexture
                    encoder.setTexture(destinationTexture, index: param.targetIndex)
                case ParameterConstantKeys.LastTexture:
                    param.texture = delegate?.filterDidRequestLastTexture(filter: self)
                    encoder.setTexture(param.texture, index: param.targetIndex)
                default:
                    encoder.setTexture(param.texture, index: param.targetIndex)
            }
        }
 
        for (key,param) in parameters.floats {
            switch key {
            case ParameterConstantKeys.Time:
                var t = time
                encoder.setBytes(&t, length: MemoryLayout<Float>.size, index: param.targetIndex)
            default:
                var v = param.currentValue
                encoder.setBytes(&v, length: MemoryLayout<Float>.size, index: param.targetIndex)
            }
        }
        
        for (_, param) in parameters.ints {
            var v = param.currentValue
            encoder.setBytes(&v, length: MemoryLayout<Int>.size, index: param.targetIndex)
        }
        
        for (_, param) in parameters.vector2s {
            var v = param.currentValue
            encoder.setBytes(&v, length: MemoryLayout<vector_float2>.size, index: param.targetIndex)
        }
        
        if (self.wantsAudio)
        {
            encoder.setBuffer(self.parameters.audioBuffer, offset: 0, index: self.parameters.audioBufferIndex!)
        }
    }
    
    func baseInit(device: MTLDevice) {} // Load the kernel, make the compute pipeline state
    
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture, time: Float)
    {
        preRender(commandBuffer: commandBuffer, _width: sourceTexture.width, _height: sourceTexture.height)
        
        #if !targetEnvironment(simulator)
        kernel.encode(commandBuffer: commandBuffer,
                      sourceTexture: sourceTexture,
                      destinationTexture: destinationTexture) { (encoder) in
            updateUniforms(encoder: encoder, sourceTexture: sourceTexture, destinationTexture: destinationTexture, time: time)
        }
        
        #endif
        
        postRender()
    }
    
    func updateTouchPositionParameter(point: CGPoint)
    {
        if let param = parameters.vector2s[ParameterConstantKeys.UserControlParameter] {
            param.updateWithPoint(v: point)
        }
    }
    
    func updateAudioParams(data: [Float])
    {
        self.parameters.audioBuffer = MetalHelper.shared.metalDevice.makeBuffer(bytes: data,
                                                                               length:MemoryLayout<Float>.size * data.count,
                                                                               options:[])!
    }
    
    func createAudioBuffer(bufferIndex: Int)
    {
        self.parameters.createAudioBuffer(bufferIndex: bufferIndex)
    }
}

extension Filter: CenteredItemViewConvertible {
    
    var rawValue: String {
        return name
    }
    var displayTitle: String? {
        return name
    }
    var displayImage: UIImage? {
        return UIImage(named: "filterIcon_\(name)")
    }
}

