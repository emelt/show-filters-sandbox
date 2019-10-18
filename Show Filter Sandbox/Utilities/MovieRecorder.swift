//
//  MovieRecorder.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 10/1/18.
//  Copyright © 2018 Mav Farm. All rights reserved.
//

import AVFoundation
import Foundation

protocol MovieRecorderDelegate: class {
    func movieRecorderDidBeginWriting(movieRecorder: MovieRecorder)
    func movieRecorderDidFinishWriting(movieRecorder: MovieRecorder, url: URL)
}

final class MovieRecorder {
    
    private var writingQueue = DispatchQueue.global(qos: .userInitiated)
    private var audioInput: AVAssetWriterInput?
    private var videoInput: AVAssetWriterInput?
    private var assetWriter: AVAssetWriter?
    private var audioFormatDescription: CMFormatDescription!
    private var videoFormatDescription: CMFormatDescription!
    var audioSettings: [String: Any]!
    var videoSettings: [String: Any]!
    private var isWriting = false
    private var isWriterConfigured = false
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var videoTransform: CGAffineTransform?
    private var recordingStartTime = CMTime.invalid
    
    weak var delegate: MovieRecorderDelegate?
    
    func stopWriting() {
        
        writingQueue.sync {
            autoreleasepool {
                self.isWriting = false
                self.isWriterConfigured = false
                self.recordingStartTime = .invalid
                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                
                self.assetWriter?.finishWriting(completionHandler: {
                    DispatchQueue.main.async {
                        if let url = self.assetWriter?.outputURL {
                            self.delegate?.movieRecorderDidFinishWriting(movieRecorder: self, url: url)
                            self.videoInput = nil
                            self.audioInput = nil
                            self.assetWriter = nil
                        }
                    }
                })
            }
            
        }
    }
    
    func startWriting() {
        
        writingQueue.sync {
            autoreleasepool {
                guard let tempFileURL = AssetHelper.createTemporaryFileURL() else { return }
                
                do {
                    self.assetWriter = try AVAssetWriter(outputURL: tempFileURL, fileType: AVFileType.mov)
                } catch {
                    self.assetWriter = nil
                }
                
                guard let writer = self.assetWriter else {
                    fatalError("assetWriter was nil")
                }
                
                DispatchQueue.main.async {
                    autoreleasepool {
                        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: self.audioSettings, sourceFormatHint: self.audioFormatDescription)
                        let videoInput = AVAssetWriterInput(mediaType: .video,
                                                            outputSettings: self.videoSettings,
                                                            sourceFormatHint: self.videoFormatDescription)
                        self.audioInput = audioInput
                        self.videoInput = videoInput
                        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                                                       sourcePixelBufferAttributes: .none)
                        
                        if let videoTransform = self.videoTransform {
                            videoInput.transform = videoTransform
                        }
                        
                        videoInput.expectsMediaDataInRealTime = true
                        audioInput.expectsMediaDataInRealTime = true
                        self.isWriterConfigured = false
                        
                        writer.add(videoInput)
                        writer.add(audioInput)
                        writer.startWriting()
                        
                        if writer.error == nil {
                            self.delegate?.movieRecorderDidBeginWriting(movieRecorder: self)
                            self.isWriting = true
                        }
                    }
                }
            }
            
        }
    }
    
    func appendTexture(_ texture: MTLTexture,
                       withPresentationTime presentationTime: CMTime) {
        writingQueue.sync {
            autoreleasepool {
                guard let pixelBuffer = MetalTextureHelper.createPixelBuffer(forTexture: texture), self.isWriting else { return }
                let startingTimeDelay = CMTimeMakeWithSeconds(0.5, preferredTimescale: 1000)
                self.recordingStartTime = CMTimeAdd(presentationTime, startingTimeDelay)
                self.configureWriter(for: self.recordingStartTime)
                
                if self.videoInput?.isReadyForMoreMediaData ?? false, self.isWriterConfigured {
                    let success = self.pixelBufferAdaptor.append(pixelBuffer,
                                                                 withPresentationTime: presentationTime)
                    if !success {
                        let error = self.assetWriter?.error
                        print(error as Any)
                    }
                } else {
                    debugPrint("Video input not ready for more media data, dropping buffer")
                }
            }
        }
    }
    
    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writingQueue.sync {
            autoreleasepool {
                guard self.isWriterConfigured, self.isWriting else { return }
                
                if self.audioInput?.isReadyForMoreMediaData ?? false {
                    let success = self.audioInput?.append(sampleBuffer)
                    if !(success ?? false) {
                        let error = self.assetWriter?.error
                        print(error as Any)
                    }
                } else {
                    debugPrint("Audio input not ready for more media data, dropping buffer")
                }
            }
        }
    }
    
    private func configureWriter(for timestamp: CMTime) {
        synchronized(self) {
            if !self.isWriterConfigured, self.assetWriter?.status.rawValue != 0 {
                self.assetWriter?.startSession(atSourceTime: timestamp)
                
                self.isWriterConfigured = true
            }
        }
    }
    
}

// MARK: Format Descriptions

extension MovieRecorder {
    
    func configureVideoFormatDescription(for texture: MTLTexture) {
        if videoFormatDescription == nil {
            if let pixelBuffer = MetalTextureHelper.createPixelBuffer(forTexture: texture) {
                var formatDescription: CMVideoFormatDescription?
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                             imageBuffer: pixelBuffer,
                                                             formatDescriptionOut: &formatDescription)
                self.videoFormatDescription = formatDescription
            }
        }
    }
    
    func configureAudioFormatDescription(forBuffer buffer: CMSampleBuffer) {
        if audioFormatDescription == nil {
            audioFormatDescription = CMSampleBufferGetFormatDescription(buffer)
        }
    }
}
