//
//  TextureLoader.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-09-01.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit
import os.log

final class TextureLoader {
    
    static var shared : TextureLoader = TextureLoader()
    
    var textureLoader : MTKTextureLoader
    var blankTexture : MTLTexture
    var metalDevice : MTLDevice
    
    private var textures: [String : MTLTexture] = [:]
    private var textureCache: CVMetalTextureCache!

    init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()!
        self.textureLoader = MTKTextureLoader(device: self.metalDevice)
        
        let imagePath = Bundle(for: TextureLoader.self).path(forResource: "blankTexture", ofType: "png")!
        let image = UIImage(contentsOfFile: imagePath)!
        self.blankTexture = textureLoader.makeTexture(image: image)!
                
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.metalDevice, nil, &textCache) != kCVReturnSuccess {
            os_log("Unable to allocate texture cache")
        }
        else {
            self.textureCache = textCache
        }
        
    }
    
    public func load(name:String, cache:Bool) -> MTLTexture? {
        if textures[name] != nil {
            return textures[name]
        }
        
        let imagePath = Bundle(for: TextureLoader.self).path(forResource: name, ofType: "png")!
        let image = UIImage(contentsOfFile: imagePath)!
        
        let tex = textureLoader.makeTexture(image: image)!
        
        if (cache)
        {
            textures[name] = tex
        }
        return tex
    }
    
    func makeTextures(from pixelBuffer: CVPixelBuffer) -> (textureY: MTLTexture?, textureCbCr: MTLTexture?) {
        let textureY    = makeTexture(from: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        let textureCbCr = makeTexture(from: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
        return (textureY, textureCbCr)
    }
    
    func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let texture = makeTexture(from: pixelBuffer, pixelFormat: .bgra8Unorm, width: width, height: height)
        return texture
    }
    
    func makeTexture(from pixelBuffer: CVPixelBuffer, pixelFormat format: MTLPixelFormat, planeIndex pIndex: Int = 0) -> MTLTexture? {
        if CVPixelBufferGetPlaneCount(pixelBuffer) < 2 {
            return nil
        }
        let width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, pIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, pIndex)
        return makeTexture(from: pixelBuffer, pixelFormat: format, width: width, height: height, planeIndex: pIndex)
    }
    
    func makeTexture(from pixelBuffer: CVPixelBuffer, pixelFormat format: MTLPixelFormat, width w: Int, height h: Int, planeIndex pIndex: Int = 0) -> MTLTexture? {
        var cvTextureOut: CVMetalTexture? = nil
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, format, w, h, pIndex, &cvTextureOut)
        
        if let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) {
            return texture
        }
        else {
            CVMetalTextureCacheFlush(textureCache, 0)
            return nil
        }
    }
}

extension MTKTextureLoader {
    func makeTexture(image: UIImage) -> MTLTexture? {
        if let cgImage = image.cgImage {
            return makeTexture(cgImage: cgImage)
        } else {
            print("[ERROR] - Failed to get a CGImage from the UIImage.")
        }
        return nil
    }
    
    func makeTexture(cgImage: CGImage) -> MTLTexture? {
        do {
            return try newTexture(cgImage: cgImage, options: [MTKTextureLoader.Option.SRGB : NSNumber(value: false)])
        } catch let error as NSError {
            print("[ERROR] - Failed to create a new MTLTexture from the CGImage. \(error)")
        }
        return nil
    }
}
