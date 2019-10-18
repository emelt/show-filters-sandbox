//
//  PhotoAlbumHelper.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 6/6/19.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Photos

final class PhotoAlbumHelper: NSObject {
    
    static let shared = PhotoAlbumHelper()
    
    //Default album
    private var assetCollection: PHAssetCollection?
    
    private override init() {
        super.init()
    
    }
    
    private func checkAuthorizationWithHandler(completion: @escaping ((_ success: Bool) -> Void)) {
        if PHPhotoLibrary.authorizationStatus() == .notDetermined {
            PHPhotoLibrary.requestAuthorization({ [weak self] _ in
                self?.checkAuthorizationWithHandler(completion: completion)
            })
        } else if PHPhotoLibrary.authorizationStatus() == .authorized {
            completion(true)
        } else {
            completion(false)
        }
    }
    
    
    func saveVideo(with fileUrl: URL,
                   name: String,
                   completion: ((Bool) -> Void)? = nil) {
        
        checkAuthorizationWithHandler { [weak self] success in

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
            }) { saved, error in
                if saved {
                
                }
            }
        }
    }
}
