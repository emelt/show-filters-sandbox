//
//  Transition.swift
//  MavFarm
//
//  Created by Colin Duffy on 8/4/19.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit

protocol TransitionDelegate {
    func transitionDidRequestLastTexture(transition: Transition) -> MTLTexture
}

class Transition {

    var name: String = ""
    var kernel: Kernel

    static let maximumDuration:Float = 0.5
    
    var startTime: Float = 0.0
    var endTime: Float = 0.0
    
    var startClip: Int = -1
    var endClip: Int = -1
    var active: Bool = false
    
    public var parameters : FilterParameters = FilterParameters()
    var author : FilterAuthor?
    public var delegate : TransitionDelegate?
    var secondTextureKey = "SecondTextureKey"
    var transitionProgressKey = "TransitionProgressKey"
    
    var duration: Float {
        get {
            return endTime - startTime
        }
    }
    
    init(device: MTLDevice, kernelName: String) {
        self.kernel = Kernel(device: device, name: kernelName)
    }
    
    func updateUniforms(encoder: MTLComputeCommandEncoder,
                        sourceTexture: MTLTexture,
                        destinationTexture: MTLTexture,
                        transitionTexture: MTLTexture,
                        time: Float,
                        transitionProgress: Float)
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
                param.texture = delegate?.transitionDidRequestLastTexture(transition: self)
                encoder.setTexture(param.texture, index: param.targetIndex)
            case secondTextureKey:
                param.texture = transitionTexture
                encoder.setTexture(transitionTexture, index: param.targetIndex)
            default:
                encoder.setTexture(param.texture, index: param.targetIndex)
            }
        }
        
        for (key,param) in parameters.floats {
            switch key {
            case ParameterConstantKeys.Time:
                var t = time
                encoder.setBytes(&t, length: MemoryLayout<Float>.size, index: param.targetIndex)
            case transitionProgressKey:
                var v = transitionProgress
                encoder.setBytes(&v, length: MemoryLayout<Float>.size, index: param.targetIndex)
            default:
                var v = param.currentValue
                encoder.setBytes(&v, length: MemoryLayout<Float>.size, index: param.targetIndex)
            }
        }
    }
    
    func encode(commandBuffer: MTLCommandBuffer,
                sourceTexture: MTLTexture,
                transitionTexture: MTLTexture,
                time: Float,
                transitionProgress: Float,
                destinationTexture: MTLTexture)
    {
        kernel.encode(commandBuffer: commandBuffer,
                      sourceTexture: sourceTexture,
                      destinationTexture: destinationTexture)
        { (encoder) in
            updateUniforms(encoder: encoder, sourceTexture: sourceTexture, destinationTexture: destinationTexture, transitionTexture:transitionTexture, time: time, transitionProgress: transitionProgress)
        }
    }
}

// MARK: Equatable Implementation

extension Transition: Equatable {
    public static func == (lhs: Transition, rhs: Transition) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Transition: CenteredItemViewConvertible {
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
