//
//  AudioBuffer.swift
//  MavFarm
//
//  Created by Connor Bell on 2019-12-26.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Accelerate
import AVFoundation
import Foundation

class AudioBuffer {
    
    fileprivate var fftSetup: FFTSetup?
    fileprivate var auBWindow = [Float](repeating: 1.0, count: 32768)

    private var audioTexture: MTLTexture?

    init() {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 128, height: 1, mipmapped: false)
        textureDescriptor.usage = .unknown
        textureDescriptor.textureType = MTLTextureType.type1D
        
        self.audioTexture = MetalHelper.shared.metalDevice.makeTexture(descriptor: textureDescriptor)
    }
    
    // from https://gist.github.com/hotpaw2/f108a3c785c7287293d7e1e81390c20b
    func doFFT_OnAudioBuffer(_ audioObject: [Float]) -> ([Float]) {
    
        let fftLen = 128

        let log2N = UInt(round(log2f(Float(fftLen))))
        var output = [Float](repeating: 0.0, count: fftLen)
        
        if fftSetup == nil {
            fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
            vDSP_blkman_window(&auBWindow, vDSP_Length(fftLen), 0)
        }
        
        var fcAudioU0 = [Float](repeating: 0.0, count: fftLen)
        var fcAudioV0 = [Float](repeating: 0.0, count: fftLen)
        
        var audoDataIndex = 0
        for jndex in 0 ..< fftLen {
            fcAudioU0[jndex] = audioObject[audoDataIndex]
            audoDataIndex += 4
        }
        
        vDSP_vmul(fcAudioU0, 1, auBWindow, 1, &fcAudioU0, 1, vDSP_Length(fftLen))
        
        var fcAudioUV = DSPSplitComplex(realp: &fcAudioU0,  imagp: &fcAudioV0 )
        vDSP_fft_zip(fftSetup!, &fcAudioUV, 1, log2N, Int32(FFT_FORWARD)); //  FFT()
        
        var tmpAuSpectrum = [Float](repeating: 0.0, count: fftLen)
        vDSP_zvmags(&fcAudioUV, 1, &tmpAuSpectrum, 1, vDSP_Length(fftLen))  // abs()
        
        var scale = Float(8.0)
        vDSP_vsmul(&tmpAuSpectrum, 1, &scale, &output, 1, vDSP_Length(fftLen))
        
        return output
    }
    
    // from https://gist.github.com/brennanMKE/dfe246bb06a4973ae40380bb915676bb
    func updateAudioBuffer(sampleBuffer: CMSampleBuffer, filter: Filter) {

        let buffer: CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)!

        var lengthAtOffset: size_t = 0
        var totalLength: size_t = 0
        var data: UnsafeMutablePointer<Int8>?

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var sampleBytes = UnsafeMutablePointer<Int16>.allocate(capacity: length)

        defer { sampleBytes.deallocate() }
        
        if CMBlockBufferCopyDataBytes(blockBuffer,
                                       atOffset: 0,
                                       dataLength: length,
                                       destination: sampleBytes) != noErr {
            return
        }

        var floats = [Float](repeating: Float(), count: length / 2)

        var pointerOffset = 0
        for index in 0 ..< (length / 2) {
            let ptr = sampleBytes + pointerOffset
            floats[(index % 1024)] = (Float(ptr.pointee) / Float(Int16.max))
            pointerOffset += 2
        }
        let fftResult = doFFT_OnAudioBuffer(floats)
        filter.updateAudioParams(data: fftResult)
    }
}
