import Foundation
import AVFoundation

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer)
    func cameraService(_ service: CameraService, didFinishRecordingTo outputFileURL: URL, error: Error?)
    func cameraService(_ service: CameraService, didEncounterError error: Error)
}

class CameraService: NSObject {
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    public var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    // We expose the session for SwiftUI CameraView wrappers if needed, 
    // but ideally we should expose the layer or handle it internally.
    // The current CameraView likely uses `AVCaptureVideoPreviewLayer(session: cameraService.captureSession)`.
    public var session: AVCaptureSession {
        return captureSession
    }
    
    weak var delegate: CameraServiceDelegate?
    
    private let videoQueue = DispatchQueue(label: "com.trytennis.camera.processing", qos: .userInitiated)
    
    // MARK: - Error Types
    enum CameraError: Error {
        case deviceNotFound
        case inputCreationFailed
        case cannotAddInput
        case cannotAddVideoOutput
        case cannotAddMovieOutput
        case permissionDenied
        
        var localizedDescription: String {
            switch self {
            case .deviceNotFound: return "Back camera not available"
            case .inputCreationFailed: return "Failed to create camera input"
            case .cannotAddInput: return "Cannot add camera input to session"
            case .cannotAddVideoOutput: return "Cannot add video output to session"
            case .cannotAddMovieOutput: return "Cannot add movie output to session"
            case .permissionDenied: return "Camera permission denied"
            }
        }
    }
    
    // MARK: - Setup
    
    override init() {
        super.init()
    }
    
    func checkPermissions() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraError.permissionDenied }
        default:
            throw CameraError.permissionDenied
        }
    }
    
    func setupCamera() async throws {
        try await checkPermissions()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                self.captureSession.beginConfiguration()
                
                do {
                    try self.setupInputs()
                    try self.setupOutputs()
                    self.configureSessionPreset()
                    self.captureSession.commitConfiguration()
                    continuation.resume()
                } catch {
                    self.captureSession.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func setupInputs() throws {
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotFound
        }
        
        try configureDevice(device)
        
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw CameraError.cannotAddInput }
        captureSession.addInput(input)
    }
    
    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        if let format = device.activeFormat.videoSupportedFrameRateRanges.first {
            let target = min(60.0, format.maxFrameRate)
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(target))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(target))
        }
    }
    
    private func setupOutputs() throws {
        // Video Data Output
        captureSession.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }.forEach { captureSession.removeOutput($0) }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        output.alwaysDiscardsLateVideoFrames = false
        
        guard captureSession.canAddOutput(output) else { throw CameraError.cannotAddVideoOutput }
        captureSession.addOutput(output)
        self.videoDataOutput = output
        
        // Movie File Output
        captureSession.outputs.compactMap { $0 as? AVCaptureMovieFileOutput }.forEach { captureSession.removeOutput($0) }
        guard captureSession.canAddOutput(movieFileOutput) else { throw CameraError.cannotAddMovieOutput }
        captureSession.addOutput(movieFileOutput)
    }
    
    private func configureSessionPreset() {
        let presets: [AVCaptureSession.Preset] = [.high, .medium, .low]
        for preset in presets {
            if captureSession.canSetSessionPreset(preset) {
                captureSession.sessionPreset = preset
                break
            }
        }
    }
    
    // MARK: - Control
    
    func startSession() async {
        guard !captureSession.isRunning else { return }
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                continuation.resume()
            }
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }
    }
    
    func startRecording(to outputFileURL: URL) {
        if let connection = movieFileOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }
        movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        }
    }
}

// MARK: - Delegates
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraService(self, didOutput: sampleBuffer)
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        delegate?.cameraService(self, didFinishRecordingTo: outputFileURL, error: error)
    }
}
