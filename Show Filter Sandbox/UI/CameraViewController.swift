//
//  CameraViewController.swift
//  CameraKit
//
//  Created by Geppy Parziale on 7/23/18.
//  Copyright © 2018 INVASIVECODE, Inc. All rights reserved.
//

import AVFoundation
import UIKit
import MetalKit
import CoreMedia
import os.log
import SnapKit
import Photos

protocol CameraViewControllerDelegate: class {
    func cameraViewDidToggleCamera(to position: AVCaptureDevice.Position)
    func cameraViewDidFinishProcessingVideo(at videoURL: URL)
}

public final class CameraViewController: UIViewController {
    
    @IBOutlet weak var recordButton : UIButton!
    @IBOutlet weak var switchCameraButton : UIButton!
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    weak var delegate: CameraViewControllerDelegate?
    var movieRecorder = MovieRecorder()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var isVideoRecording = false
    
    internal let session = AVCaptureSession()
    var videoDevice: AVCaptureDevice?
    private var setupResult = SessionSetupResult.success
    #if !targetEnvironment(simulator)
    private var metalView = MetalView()
    #endif
    private var filter: Filter = MetalHelper.shared.invertFilter
    
    internal var currentCameraPosition: AVCaptureDevice.Position
    private let referenceTime: CFTimeInterval = CFAbsoluteTimeGetCurrent()
    private var hasConfiguredOutputs: Bool = false
    private let sessionQueue = DispatchQueue(label: "com.mavfarm.camera.sessionQueue", qos: .background)
    private let audioQueue = DispatchQueue(label: "com.mavfarm.camera.audioQueue")
    private let videoQueue = DispatchQueue(label: "com.mavfarm.camera.videoQueue")
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    override public var shouldAutorotate: Bool {
        return false
    }
    
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: Lifecycle
    
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        self.currentCameraPosition = .back
        super.init(coder: aDecoder)
    }
    
    deinit {
        self.audioDeviceInput = nil
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        performInitialSetup()
        recordButton.addTarget(self, action:#selector(recordTapped), for: .touchUpInside)
        switchCameraButton.addTarget(self, action:#selector(switchCamera), for: .touchUpInside)
        
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
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            self?.prepareViewForDisplay()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            self?.stopSession()
        }
    }
    
    public override func viewWillTransition(to size: CGSize,
                                            with coordinator: UIViewControllerTransitionCoordinator) {
        updateVideoTransformationsForCurrentOrientation()
    }
    
    @objc func recordTapped() {
        if isVideoRecording {
            recordButton.setImage(UIImage(named: "Play"), for: .normal)
            stopRecording()
        }
        else {
            recordButton.setImage(UIImage(named: "Stop"), for: .normal)
            startRecording()
        }
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
        view.insertSubview(metalView, belowSubview: recordButton)
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

// MARK: CameraViewRepresentable Implementation
extension CameraViewController: CameraViewRepresentable {
    
    func applyFilter(filter: Filter) {
        self.filter = filter
    }
    
    func startRecording() {
        sessionQueue.async { [weak self] in
            self?.addAudioInput()
            
            DispatchQueue.main.async {
                guard let videoSettings = self?.videoOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov),
                    let audioSettings = self?.audioOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: Any] else { return }
                
                self?.movieRecorder.videoSettings = videoSettings
                self?.movieRecorder.audioSettings = audioSettings
                self?.movieRecorder.startWriting()
            }
        }
    }
    
    func stopRecording() {
        guard isVideoRecording else { return }
        sessionQueue.async { [weak self] in
            self?.removeAudioInput()
            
            DispatchQueue.main.async { [weak self] in
                self?.movieRecorder.stopWriting()
            }
        }
    }
    
    @objc func switchCamera() {
        guard !isVideoRecording else { return }
        
        sessionQueue.async { [weak self] in
            self?.toggleCurrentCamera()
        }
    }
    
    func configureDevice(for fps: FPS, completion: @escaping (() -> Void)) {
        
        switch fps {
        case .normal:
            sessionQueue.sync { [weak self] in
                self?.rebootCamera()
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateVideoTransformationsForCurrentOrientation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: completion)
                }
            }
        case .slowmo:
            sessionQueue.sync { [weak self] in
                self?.rebootCamera()
                self?.updateDeviceFormat(for: fps)
                DispatchQueue.main.async { [weak self] in
                    self?.updateVideoTransformationsForCurrentOrientation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: completion)
                }
            }
        }
    }
    
    private func updateDeviceFormat(for fps: FPS) {
        
        guard let device = videoDevice,
            let formatProperties = createFormatProperties(forDevice: device, withFramerate: fps) else {
                DispatchQueue.main.async { [weak self] in
                    self?.showErrorAlert(withTitle: Localized("error"),
                                         message: Localized("camera_doesnt_support_framerate"))
                }
                return
        }
        
        do {
            try applyFormat(format: formatProperties.format,
                            forDevice: device,
                            minFrameDuration: formatProperties.maxFrameDuration,
                            maxFrameDuration: formatProperties.maxFrameDuration)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showErrorAlert(withTitle: Localized("error"),
                                     message: Localized("camera_configure_failed"))
            }
        }
    }
    
    private func applyFormat(format: AVCaptureDevice.Format,
                             forDevice device: AVCaptureDevice,
                             minFrameDuration: CMTime,
                             maxFrameDuration: CMTime) throws {
        try device.lockForConfiguration()
        device.activeFormat = format
        device.activeVideoMinFrameDuration = minFrameDuration
        device.activeVideoMaxFrameDuration = maxFrameDuration
        device.unlockForConfiguration()
    }
    
    func zoom(delta: CGFloat) {
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            let desiredValue = device.videoZoomFactor + delta
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            let zoomFactor = max(1.0, min(desiredValue, maxZoomFactor))
            device.videoZoomFactor = zoomFactor
        } catch {
            debugPrint(error)
        }
    }
}

// MARK: Session Interactors
/*
 All of these functions must be called from the sessionQueue
 */

extension CameraViewController {
    
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
                self?.promptToAppSettings()
            }
        case .configurationFailed:
            DispatchQueue.main.async { [weak self] in
                self?.showErrorAlert(withTitle: Localized("error"),
                                     message: Localized("media_capture_error"))
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
    
    private func addAudioInput() {
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            self.audioDeviceInput = audioDeviceInput
            
            session.beginConfiguration()
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            }
            else {
                print("Could not add audio device input to the session")
            }
            session.commitConfiguration()
        }
        catch {
            print("Could not create audio device input: \(error)")
        }
    }
    
    private func removeAudioInput() {
        if let audioDeviceInput = self.audioDeviceInput {
            session.beginConfiguration()
            session.removeInput(audioDeviceInput)
            session.commitConfiguration()
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
        
        dataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        self.videoOutput = dataOutput
        
        let audioOutput = AVCaptureAudioDataOutput()
        
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        self.audioOutput = audioOutput
        session.commitConfiguration()
        hasConfiguredOutputs = true
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
    
    private func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    private func rebootCamera() {
        session.stopRunning()
        removeSessionInputs()
        configureSession()
        session.startRunning()
    }
    
    private func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    private func removeSessionInputs() {
        session.inputs.forEach({ input in
            session.removeInput(input)
        })
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate Implementation
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        if output == videoOutput {
            synchronized(self) {
                processVideoOutput(output, didOutput: sampleBuffer, from: connection)
            }
        } else if output == audioOutput {
            synchronized(self) {
                processAudioOutput(output, didOutput: sampleBuffer, from: connection)
            }
        }
    }
    
    private func processVideoOutput(_ output: AVCaptureOutput,
                                    didOutput sampleBuffer: CMSampleBuffer,
                                    from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let texture = createTexture(for: filter, buffer: pixelBuffer) else { return }
        
        #if !targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.metalView.drawableSize = CGSize(width: width, height: height)
            self.metalView.inputTexture = texture
        }
        #endif
        
        guard isVideoRecording else { return }
        movieRecorder.configureVideoFormatDescription(for: metalView.inputTexture!)
        movieRecorder.appendTexture(texture, withPresentationTime: presentationTime)
    }
    
    private func createTexture(for filter: Filter?, buffer: CVImageBuffer) -> MTLTexture? {
        guard let filter = filter else { return nil }
        
        let time = CFAbsoluteTimeGetCurrent() - referenceTime
        return FilterHelper.shared.applyFilter(to: buffer,
                                               filter: filter,
                                               time: Float(time))
    }
    
    private func processAudioOutput(_ output: AVCaptureOutput,
                                    didOutput sampleBuffer: CMSampleBuffer,
                                    from connection: AVCaptureConnection) {
        
        movieRecorder.configureAudioFormatDescription(forBuffer: sampleBuffer)
        
        guard isVideoRecording else { return }
        movieRecorder.appendAudioSampleBuffer(sampleBuffer)
    }
}

// MARK: MovieRecorderDelegate Implementation
extension CameraViewController: MovieRecorderDelegate {
    
    func movieRecorderDidBeginWriting(movieRecorder: MovieRecorder) {
        isVideoRecording = true
    }
    
    func movieRecorderDidFinishWriting(movieRecorder: MovieRecorder, url: URL) {
        isVideoRecording = false
        self.delegate?.cameraViewDidFinishProcessingVideo(at: url)
        
        requestPhotoLibraryAccess(completionHandler: { granted in
            if granted {
                PhotoAlbumHelper.shared.saveVideo(with: url, name: "", completion: { [weak self] success in
                    
                    DispatchQueue.main.async {
                        if success {
                          //  self?.view?.showSaveToStudioSuccessTip()
                        } else {
                         //   self?.view?.presentErrorAlert(withMessage: Localized("video_export_error"))
                        }
                    }
                })
            } else {
                DispatchQueue.main.async {
                    //LoadingHandler.shared.defaultLoading.stopLoading()
                    //self.view?.presentErrorAlert(withMessage: Localized("photo_access_denied"))
                }
            }
        })
    }
}

// MARK: Actions
extension CameraViewController {
    
    private func promptToAppSettings() {
        let alertController = UIAlertController(title: Localized("Error"),
                                                message: Localized("camera_permission_error"),
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: Localized("OK"),
                                                style: .cancel,
                                                handler: nil))
        alertController.addAction(UIAlertAction(title: Localized("Settings"),
                                                style: .default, handler: { action in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                      options: [:],
                                      completionHandler: nil)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func showErrorAlert(withTitle title: String?, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: Localized("ok"), style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
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

// MARK: Helpers
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
    
    func requestPhotoLibraryAccess(completionHandler handler: ((Bool) -> Swift.Void)?) {
        let authStatus = PHPhotoLibrary.authorizationStatus()
        
        switch authStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
                if let handler = handler {
                    switch status {
                    case .authorized:
                        handler(true)
                    default:
                        handler(false)
                    }
                }
            })
        case .authorized:
            if let handler = handler {
                handler(true)
            }
        case .restricted, .denied:
            if let handler = handler {
                handler(false)
            }
        }
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

// MARK: - UICollectionViewDataSource
extension CameraViewController : UICollectionViewDelegate, UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return MetalHelper.shared.filters.count;
    }

     public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellId : String = "FilterCollectionViewCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! FilterCollectionViewCell
        cell.iconImageView!.image = UIImage(named: MetalHelper.shared.filters[indexPath.row].name)
        cell.titleLabel!.text = MetalHelper.shared.filters[indexPath.row].name
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        filter = MetalHelper.shared.filters[indexPath.row]
    }
}
