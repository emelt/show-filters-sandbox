//
//  ViewController.swift
//  Show Filter Sandbox
//
//  Created by Connor Bell on 2019-10-07.
//  Copyright © 2019 Mav Farm. All rights reserved.
//

import UIKit
import MetalKit
import CoreMedia
import AVFoundation

class CameraViewController: UIViewController {

    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    internal let session = AVCaptureSession()
    var videoDevice: AVCaptureDevice?
    var movieRecorder = MovieRecorder()

    private var setupResult = SessionSetupResult.success
    #if !targetEnvironment(simulator)
    private var metalView = MetalView()
    #endif
    internal var currentCameraPosition: AVCaptureDevice.Position
    private let referenceTime: CFTimeInterval = CFAbsoluteTimeGetCurrent()
    private var filter: Filter
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var isVideoRecording = false
    
    private let sessionQueue = DispatchQueue(label: "com.mavfarm.camera.sessionQueue", qos: .background)
    private let audioQueue = DispatchQueue(label: "com.mavfarm.camera.audioQueue")
    private let videoQueue = DispatchQueue(label: "com.mavfarm.camera.videoQueue")
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var hasConfiguredOutputs: Bool = false

    convenience init() {
        self.init(cameraPosition: .back, filter: MetalHelper.shared.passthroughKernel)
    }
    
    init(cameraPosition: AVCaptureDevice.Position, filter: Filter) {
        self.currentCameraPosition = cameraPosition
        self.filter = filter
        super.init(nibName: nil, bundle: nil)
        performInitialSetup()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized: break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
        
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    override public var shouldAutorotate: Bool {
        return false
    }
    
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func prepareViewForDisplay() {
        
        switch setupResult {
        case .success:
            session.startRunning()
            configureSessionOutputs()
            DispatchQueue.main.async { [weak self] in
                self?.updateVideoTransformationsForCurrentOrientation()
            }
        case .notAuthorized:
            DispatchQueue.main.async { [weak self] in
                //self?.promptToAppSettings()
            }
        case .configurationFailed:
            DispatchQueue.main.async { [weak self] in
                //self?.showErrorAlert(withTitle: "error",
                //                   message: "media_capture_error")
            }
        }
    }
    
    private func configureSession() {
        guard setupResult == .success else {
            return
        }
        
        session.beginConfiguration()
        configureVideoPreset()
        addVideoInput()
        session.commitConfiguration()
    }
    
    private func configureVideoPreset() {
        
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
    }
    
    private func addVideoInput() {
        videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            device.unlockForConfiguration()
            
            let deviceInput = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
            }
        } catch {
            setupResult = .configurationFailed
        }
    }
    
    private func configureSessionOutputs() {
        guard !hasConfiguredOutputs else { return }
        session.beginConfiguration()
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        dataOutput.alwaysDiscardsLateVideoFrames = false
        
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
        }
        
        dataOutput.setSampleBufferDelegate(self as! AVCaptureVideoDataOutputSampleBufferDelegate, queue: videoQueue)
        self.videoOutput = dataOutput
        
        let audioOutput = AVCaptureAudioDataOutput()
        
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        
        audioOutput.setSampleBufferDelegate(self as! AVCaptureAudioDataOutputSampleBufferDelegate, queue: audioQueue)
        self.audioOutput = audioOutput
        session.commitConfiguration()
        hasConfiguredOutputs = true
    }
    
    private func rebootCamera() {
        session.stopRunning()
        removeSessionInputs()
        configureSession()
        session.startRunning()
    }
    
    private func removeSessionInputs() {
        session.inputs.forEach({ input in
            session.removeInput(input)
        })
    }
    
    private func toggleCurrentCamera() {
        
        guard session.isRunning else { return }
        currentCameraPosition = currentCameraPosition.oppositePosition
        rebootCamera()
        
        DispatchQueue.main.async { [weak self] in
            self?.updateVideoTransformationsForCurrentOrientation()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.cameraViewDidToggleCamera(to: self.currentCameraPosition)
        }
    }
    
    private func updateVideoTransformationsForCurrentOrientation() {
        guard let connection = videoOutput?.connection(with: .video),
            connection.isVideoOrientationSupported else { return }
        
        connection.videoOrientation = calculatePreviewLayerOrientation()
        connection.isVideoMirrored = currentCameraPosition == .front
        movieRecorder.videoSettings =
            videoOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
    }
}

// MARK: Setup
extension CameraViewController {
    
    private func performInitialSetup() {
        setupSubviews()
        applyConstraints()
    }
    
    private func setupSubviews() {
        movieRecorder.delegate = self
        
        #if !targetEnvironment(simulator)
        view.addSubview(metalView)
        #endif
    }
    
    private func applyConstraints() {
        #if !targetEnvironment(simulator)
        metalView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        #endif
    }
}

extension CameraViewController {
    
    private func calculatePreviewLayerOrientation() -> AVCaptureVideoOrientation {
        
        switch UIDevice.current.orientation {
        case .portrait, .unknown, .faceUp, .faceDown:
            return .portrait
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        }
    }
    
    private func createFormatProperties(forDevice device: AVCaptureDevice,
                                        withFramerate framerate: FPS) -> (format: AVCaptureDevice.Format, minFrameDuration: CMTime, maxFrameDuration: CMTime)? {
        
        for vFormat in device.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            if frameRates.maxFrameRate == framerate.rawValue {
                return (format: vFormat,
                        minFrameDuration: frameRates.minFrameDuration,
                        maxFrameDuration: frameRates.minFrameDuration)
            }
        }
        
        return nil
    }
}

extension AVCaptureDevice.Position {
    
    var oppositePosition: AVCaptureDevice.Position {
        switch self {
        case .front, .unspecified:
            return .back
        case .back:
            return .front
        @unknown default:
            return .back
        }
    }
}
