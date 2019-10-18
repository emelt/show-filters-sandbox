//
//  MetalTexture+Helpers.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 9/28/18.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

import Foundation
import MetalKit

struct MetalTextureHelper {
    
    /*
     The below function is expensive, avoid calling unless necessary
     */
    
    static func createPixelBuffer(forTexture texture: MTLTexture) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            texture.width,
                            texture.height,
                            kCVPixelFormatType_32BGRA,
                            nil,
                            &buffer)
        
        guard let pxBuffer = buffer else { return buffer }
        
        // The number of bytes for each image row
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer)
        
        CVPixelBufferLockBaseAddress(pxBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Gets the bytes from the texture
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        
        let tempBuffer = CVPixelBufferGetBaseAddress(pxBuffer)
        
        texture.getBytes(tempBuffer!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        CVPixelBufferUnlockBaseAddress(pxBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxBuffer
    }
}
