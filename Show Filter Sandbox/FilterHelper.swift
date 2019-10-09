//
//  FilterHelper.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 12/11/17.
//  Copyright © 2017 Mav Farm. All rights reserved.
//

import AVFoundation
import Foundation
import MetalPerformanceShaders
import CoreImage

final class FilterHelper {
    
    private let videoProcessor = VideoProcessor()
    static let shared = FilterHelper()
    private let videoInputQueue = DispatchQueue(label: "com.mavfarm.filterWriter.videoQueue")
    private let audioInputQueue = DispatchQueue(label: "com.mavfarm.filterWriter.audioQueue")
    
    let filter = Event<(String, Filter)>()
    
    func addFilter(to asset: AVAsset,
                   with filter: Filter,
                   outputURL: URL,
                   progress: @escaping ((Float) -> Void),
                   completion: @escaping (URL?) -> Void) {
        
        var assetReader: AVAssetReader?
        var assetWriter: AVAssetWriter?
        var audioFinished = false
        var videoFinished = false

        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader,
            let videoTrack = asset.tracks(withMediaType: .video).first else {
            fatalError("Could not initalize asset reader probably failed its try catch")
        }
        
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        let naturalSize = videoTrack.naturalSize
        var presentingSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        
        presentingSize.width = abs(presentingSize.width)
        presentingSize.height = abs(presentingSize.height)
        
        videoProcessor.filter = filter
        videoProcessor.inputWidth = Int(presentingSize.width)
        videoProcessor.inputHeight = Int(presentingSize.height)
        
        let videoReaderSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // ADJUST BIT RATE OF VIDEO HERE
        let bitrate = [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
        let videoSettings: [String: Any] = [
            AVVideoCompressionPropertiesKey: bitrate,
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: presentingSize.height,
            AVVideoWidthKey: presentingSize.width]
        
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        
        if reader.canAdd(assetReaderVideoOutput) {
            reader.add(assetReaderVideoOutput)
        } else {
            fatalError("Couldn't add video output reader")
        }
        
        var assetReaderAudioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTrack {
            assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            
            if reader.canAdd(assetReaderAudioOutput!) {
                reader.add(assetReaderAudioOutput!)
            } else {
                fatalError("Couldn't add audio output reader")
            }
        }
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        videoInput.expectsMediaDataInRealTime = false
        
        // we need to add samples to the video input
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        } catch {
            assetWriter = nil
        }
        
        guard let writer = assetWriter else {
            fatalError("assetWriter was nil")
        }
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                                      sourcePixelBufferAttributes: videoReaderSettings)
        
        writer.shouldOptimizeForNetworkUse = false
        writer.add(videoInput)
        if audioTrack != nil {
            writer.add(audioInput)
        }
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        let closeWriter:() -> Void = {
            if audioFinished && videoFinished {
                assetWriter?.finishWriting(completionHandler: {
                    DispatchQueue.main.async {
                        completion(assetWriter?.outputURL)
                    }
                })
                assetReader?.cancelReading()
            }
        }
        
        if audioTrack != nil {
            audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
                while audioInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        if let sample = assetReaderAudioOutput?.copyNextSampleBuffer() {
                            audioInput.append(sample)
                        } else {
                            audioInput.markAsFinished()
                            DispatchQueue.main.async {
                                audioFinished = true
                                closeWriter()
                            }
                        }
                    }
                }
            }
        } else {
            audioFinished = true
            closeWriter()
        }
        
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) { [weak self] in
            
            while videoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if let sample = assetReaderVideoOutput.copyNextSampleBuffer(),
                        let imageBufferRef = CMSampleBufferGetImageBuffer(sample) {
                        let time = CMSampleBufferGetPresentationTimeStamp(sample)
                        
                        let durationTime = CMTimeGetSeconds(asset.duration)
                        let timeSecond = CMTimeGetSeconds(time)
                        
                        progress(Float(timeSecond / durationTime))
                        
                        self?.videoProcessor.time = Float(time.seconds)
                        #if !targetEnvironment(simulator)
                        if let texture = self?.videoProcessor.process(imageBufferRef),
                            let buffer = MetalTextureHelper.createPixelBuffer(forTexture: texture) {
                            pixelBufferAdaptor.append(buffer, withPresentationTime: time)
                        }
                        #endif
                    } else {
                        videoInput.markAsFinished()
                        DispatchQueue.main.async {
                            videoFinished = true
                            closeWriter()
                        }
                    }
                }
            }
        }
    }
    
    func convertImageToMetalTexture(ciImage: CIImage) -> MTLTexture? {
        let context = CIContext()
        #if !targetEnvironment(simulator)
        return videoProcessor.newTexture(CIImage: ciImage, context: context)
        #else
        return nil
        #endif
    }
    
    func applyFilter(to pixelBuffer: CVPixelBuffer, filter: Filter, time: Float) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        videoProcessor.filter = filter
        videoProcessor.inputWidth = Int(width)
        videoProcessor.inputHeight = Int(height)
        videoProcessor.time = Float(time)
        
        guard let texture = videoProcessor.process(pixelBuffer)
            else { return nil }
        
        return texture
    }
    
    func applyFilter(to metalTexture: MTLTexture, filter: Filter, time: Float) -> MTLTexture? {
        let width = metalTexture.width
        let height = metalTexture.height
        
        videoProcessor.filter = filter
        videoProcessor.inputWidth = Int(width)
        videoProcessor.inputHeight = Int(height)
        videoProcessor.time = Float(time)
        
        guard let texture = videoProcessor.process(metalTexture)
            else { return nil }
        
        return texture
    }
    
    
    func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        return TextureLoader.shared.makeTexture(from: pixelBuffer)
    }
}
