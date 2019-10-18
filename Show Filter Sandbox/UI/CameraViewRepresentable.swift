//
//  CameraViewRepresentable.swift
//  MavFarm
//
//  Created by Stephen Walsh on 07/03/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import AVKit

protocol CameraViewRepresentable: class {
    
    var delegate: CameraViewControllerDelegate? { get set }
    var currentCameraPosition: AVCaptureDevice.Position { get set }
    
    func applyFilter(filter: Filter)
    func startRecording()
    func stopRecording()
    func configureDevice(for fps: FPS, completion: @escaping (() -> Void))
    func switchCamera()
    func zoom(delta: CGFloat)
}
