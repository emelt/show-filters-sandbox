//
//  AssetHelper.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 11/27/17.
//  Copyright © 2017 Mav Farm. All rights reserved.
//

import AVFoundation
import Foundation

struct AssetHelper {
    
    enum Constants {
        static let defaultFrameRate: CGFloat = 30.0
        static let bestQualityFrameRate: CGFloat = 60.0
    }
    
    @discardableResult
    static func export(asset: AVAsset,
                       isMuted: Bool,
                       animationTool: AVVideoCompositionCoreAnimationTool? = nil,
                       completion: @escaping (URL?) -> Void) -> AVAssetExportSession? {
        guard let composition = AssetHelper.composition(for: asset, byRemoving: nil, to: nil),
            let exportSession = AssetHelper.exportSession(for: composition) else {
                completion(nil)
                return nil
        }
        
        if isMuted {
            let audioTracks = composition.tracks(withMediaType: .audio)
            for track in audioTracks {
                composition.removeTrack(track)
            }
        }
        
        exportSession.exportAsynchronously {
            completion(exportSession.outputURL)
        }
        
        return exportSession
    }
    
    @discardableResult
    static func exportSlowmo(asset: AVAsset,
                             fromSecond: CMTime,
                             toSecond: CMTime,
                             completion: @escaping (URL?) -> Void) -> AVAssetExportSession? {
        guard let composition = AssetHelper.composition(for: asset, bySlowing: fromSecond, to: toSecond),
            let exportSession = AssetHelper.exportSession(for: composition) else {
                completion(nil)
                return nil
        }
        
        exportSession.exportAsynchronously {
            completion(exportSession.outputURL)
        }
        
        return exportSession
    }
    
    static func clearFolder() {
        DispatchQueue.global().async {
            if let documentsUrl = FileManager.default.urls(for: .documentDirectory,
                                                           in: .userDomainMask).first {
                deleteContents(atURL: documentsUrl, withFilter: { (url) -> Bool in
                    url.pathExtension == "mov"
                })
            }
            
            if let tempURL = LocalURLBuilder.fetchTempFileFolder() {
                deleteContents(atURL: tempURL, withFilter: { (url) -> Bool in
                    return true
                })
            }
        }
    }
    
    static func createTemporaryFileURL() -> URL? {
        let fileName = "\(String.randomString(length: 10)).mov"
        return LocalURLBuilder.createTempFileURL(withFileName: fileName)
    }
}

// MARK: Helpers

extension AssetHelper {
    
    private static func createExportComposition() -> AVMutableComposition {
        let composition = AVMutableComposition()
        composition.naturalSize = CGSize(width: 1080, height: 1920)
        
        return composition
    }
    
    private static func exportSession(for asset: AVAsset) -> AVAssetExportSession? {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough),
            exportSession.supportedFileTypes.contains(AVFileType.mov) else {
                return nil
        }
        
        exportSession.outputURL = createTemporaryFileURL()
        exportSession.outputFileType = AVFileType.mov
        exportSession.shouldOptimizeForNetworkUse = false
        
        return exportSession
    }
    
    private static func composition(for asset: AVAsset,
                                    bySlowing from: CMTime?,
                                    to: CMTime?) -> AVMutableComposition? {
        
        guard let sourceVideoTrack = asset.tracks(withMediaType: AVMediaType.video).first, let from = from, let to = to else {
            return nil
        }
        
        let duration = asset.duration
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        if let transform = asset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform {
            compositionVideoTrack?.preferredTransform = transform
        }
        
        try? compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: sourceVideoTrack, at: CMTime.zero)
        
        var timeRange: CMTimeRange?
        var finalTimeScale: Int64?
        var fps: CGFloat = 0.0
        
        if let compositionVideoTrack = compositionVideoTrack {
            fps = CGFloat(compositionVideoTrack.nominalFrameRate)
            
            if fps > AssetHelper.Constants.bestQualityFrameRate {
                let multiplier = fps / AssetHelper.Constants.defaultFrameRate
                let timeDifference = CMTimeGetSeconds(to) - CMTimeGetSeconds(from)
                timeRange = compositionVideoTrack.timeRange
                finalTimeScale = Int64((timeDifference) * Double(duration.timescale) * Double(multiplier))
                compositionVideoTrack.scaleTimeRange(CMTimeRangeMake(start: from, duration: to), toDuration: CMTimeMake(value: finalTimeScale!, timescale: duration.timescale))
            }
        }
        
        if let sourceAudioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
            
            try? compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: sourceAudioTrack, at: CMTime.zero)
            if timeRange != nil, let finalTimeScale = finalTimeScale {
                compositionAudioTrack?.scaleTimeRange(CMTimeRangeMake(start: from, duration: to), toDuration: CMTimeMake(value: finalTimeScale, timescale: duration.timescale))
            }
        }
        
        return composition
    }
    
    private static func composition(for asset: AVAsset,
                                    byRemoving from: CMTime?,
                                    to: CMTime?) -> AVMutableComposition? {
        guard let sourceVideoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
            return nil
        }
        
        let duration = asset.duration
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        if let transform = asset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform {
            compositionVideoTrack?.preferredTransform = transform
        }
        
        if let from = from, let to = to {
            try? compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: from), of: sourceVideoTrack, at: CMTime.zero)
            try? compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: to, duration: duration), of: sourceVideoTrack, at: from)
        } else {
            try? compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: sourceVideoTrack, at: CMTime.zero)
        }
        
        if let sourceAudioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
            
            if let from = from, let to = to {
                try? compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: from), of: sourceAudioTrack, at: CMTime.zero)
                try? compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: to, duration: duration), of: sourceAudioTrack, at: from)
                
            } else {
                try? compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: sourceAudioTrack, at: CMTime.zero)
            }
        }
        
        return composition
    }
    
    private static func createComposition(forAsset asset: AVAsset,
                                          trimStartRatio: Double? = nil,
                                          trimEndRatio: Double? = nil) -> AVComposition? {
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video,
                                                     preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        var audioTrack: AVMutableCompositionTrack?
        
        guard let video = asset.tracks(withMediaType: AVMediaType.video).first else { return nil }
        
        let startVideoTime = CMTime(seconds: (video.timeRange.duration.seconds * (trimStartRatio ?? 0)),
                                    preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        let endVideoTime = CMTime(seconds: (video.timeRange.duration.seconds * (trimEndRatio ?? 1)),
                                    preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Apply video
        do {
            let videoTime = CMTime.zero
            try videoTrack?.insertTimeRange(CMTimeRangeFromTimeToTime(start: startVideoTime, end: endVideoTime),
                                            of: video,
                                            at: videoTime)
        } catch let error as NSError {
            debugPrint("error: \(error)")
        }
        
        // Apply video transform if applicable
        
        if let transform = asset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform {
            videoTrack?.preferredTransform = transform
        }
        
        // Add audio if it exists and the asset hasn't been muted
        
        if let audio = asset.tracks(withMediaType: AVMediaType.audio).first {
            
            if audioTrack == nil {
                audioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                         preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            }
            
            do {
                let audioTime = CMTime.zero
                try audioTrack?.insertTimeRange(CMTimeRangeFromTimeToTime(start: startVideoTime, end: endVideoTime),
                                                of: audio,
                                                at: audioTime)
            } catch let error as NSError {
                debugPrint("error rendering audio: \(error)")
            }
        }
    
        return composition
    }
    
    private static func deleteContents(atURL url: URL,
                                       withFilter filter: ((URL) -> Bool)) {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: url,
                                                                                includingPropertiesForKeys: nil, options: [])
            let movFiles = directoryContents.filter { filter($0) }
            for file in movFiles {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            debugPrint("*** Can't remove existing mov files error: \(error.localizedDescription)")
        }
    }
}
