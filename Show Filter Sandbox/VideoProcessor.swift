//
//  VideoProcessor.swift
//  MetalCamera
//
//  Created by Geppy Parziale on 7/17/18.
//  Copyright © 2018 INVASIVECODE, Inc. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders
import CoreVideo
import CoreMedia

#if targetEnvironment(simulator)
class VideoProcessor {
    var filter: Filter?
    var time: Float = 0
    var inputWidth: Int = 1080
    var inputHeight: Int = 1920
    func process(_ pixelBuffer: CVPixelBuffer, transitionTexture:MTLTexture) -> MTLTexture? {
        return nil
    }
    
    func process(_ texture: MTLTexture?, transitionTexture:MTLTexture) -> MTLTexture?  {
        return nil
    }
}
#else

class VideoProcessor: NSObject, FilterDelegate, TransitionDelegate {
    
    var inputTexture: MTLTexture?
    var lastTexture: MTLTexture?
    var filter: Filter? {
        willSet {
            newValue!.delegate = self;
            
            if newValue != filter {

                if (filter != nil)
                {
                    filter!.stop()
                }

                newValue!.start()
            }
        }
    }
    var time: Float = 0
    var transitions: [Transition] = []
    var currentTransition:Int = -1
    
    var inputWidth: Int = 1080 {
        didSet {
            if inputWidth != oldValue {
                self.convertedTextureDescriptor.width = inputWidth
            }
        }
    }
    
    var inputHeight: Int = 1920 {
        didSet {
            if inputHeight != oldValue {
                self.convertedTextureDescriptor.height = inputHeight
            }
        }
    }

    private var convertedTextureDescriptor: MTLTextureDescriptor
    
    var isTransitioning:Bool = false
    var transitionsDuration: Float {
        var total: Float = 0.0
        
        for (transition) in transitions.enumerated() {
            total += transition.element.duration
        }
        
        return total
    }

    override init() {
        self.convertedTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: inputWidth, height: inputHeight, mipmapped: false)
        self.convertedTextureDescriptor.usage = .unknown
        
        self.lastTexture = MetalHelper.shared.metalDevice.makeTexture(descriptor: convertedTextureDescriptor)
        self.filter = .none
        
        super.init()
    }

    func process(_ pixelBuffer: CVPixelBuffer, rotate:Bool) -> MTLTexture? {
        guard let commandBuffer = MetalHelper.shared.commandQueue.makeCommandBuffer(),
            var convertedTexture  = MetalHelper.shared.metalDevice.makeTexture(descriptor: self.convertedTextureDescriptor),
            let outputTexture = MetalHelper.shared.metalDevice.makeTexture(descriptor: self.convertedTextureDescriptor)
            else { return nil }
  
        /*
        if rotate {
            if let inputTexture = TextureLoader.shared.makeTexture(from: pixelBuffer) {
                MetalHelper.shared.rotateKernel.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, time: 0, destinationTexture: convertedTexture)
            }
        }
        else {
 */
            guard let inputTexture = TextureLoader.shared.makeTexture(from: pixelBuffer) else { return nil }
            convertedTexture = inputTexture
   //     }

        if let filter = filter {
            if filter != MetalHelper.shared.passthroughKernel {
                encode(filter: filter, commandBuffer: commandBuffer, convertedTexture: convertedTexture, time: time, outputTexture: outputTexture)
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            else {
                return convertedTexture
            }
        }
        
        lastTexture = outputTexture
        return outputTexture
    }
    

    func process(_ texture: MTLTexture? ) -> MTLTexture? {
        guard let inputTexture = texture,
            var convertedTexture  = MetalHelper.shared.metalDevice.makeTexture(descriptor: self.convertedTextureDescriptor),
            let commandBuffer = MetalHelper.shared.commandQueue.makeCommandBuffer(),
            let outputTexture = MetalHelper.shared.metalDevice.makeTexture(descriptor: convertedTextureDescriptor)
            else { return nil }
        
        if let filter = filter {

            encode(filter: filter, commandBuffer: commandBuffer, convertedTexture: convertedTexture, time: time, outputTexture: outputTexture)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        lastTexture = outputTexture

        return outputTexture
    }
    
    private func encode(filter: Filter, commandBuffer: MTLCommandBuffer, convertedTexture: MTLTexture, time: Float, outputTexture: MTLTexture) {
        filter.encode( commandBuffer: commandBuffer, sourceTexture: convertedTexture, destinationTexture: outputTexture, time: time )
    }
    
    func filterDidRequestLastTexture(filter: Filter) -> MTLTexture {
        return lastTexture!
    }

    func transitionDidRequestLastTexture(transition: Transition) -> MTLTexture {
        return lastTexture!
    }
}
#endif

#if !targetEnvironment(simulator)
extension VideoProcessor {
    func newTexture(CIImage: CIImage, context: CIContext, mips: Int = 1) -> MTLTexture {
        
        let colorspace = CIImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        convertedTextureDescriptor.height = Int(CIImage.extent.height)
        convertedTextureDescriptor.width = Int(CIImage.extent.width)
        
        let metalTexture = MetalHelper.shared.metalDevice.makeTexture(descriptor: convertedTextureDescriptor)
        let cmdBuffer = MetalHelper.shared.commandQueue.makeCommandBuffer()
        
        context.render(CIImage, to: metalTexture!, commandBuffer: cmdBuffer, bounds: CIImage.extent, colorSpace: colorspace)
        
        if metalTexture!.mipmapLevelCount > 1 {
            let encoder = cmdBuffer?.makeBlitCommandEncoder()
            encoder?.generateMipmaps(for: metalTexture!)
            encoder?.endEncoding()
        }
        cmdBuffer?.commit()
        return metalTexture!
    }
}
#endif

