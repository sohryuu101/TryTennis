import Foundation
import AVFoundation
import CoreML
import Photos
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity

/// ViewModel for Camera and Live Analysis feature
/// Note: Inherits from NSObject (not BaseViewModel) due to AVFoundation delegate requirements
/// Follows MVVM by delegating business logic to services
class CameraViewModel: NSObject, ObservableObject {
    
    private enum CameraSetupError: Error {
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
    
    // --- Published UI State ---
    @Published var strokeClassification: String = "Ready"
    @Published var isProcessing = false
    @Published var player: AVPlayer?
    @Published var isVideoReady = false
    @Published var totalAttempts: Int = 0
    @Published var successfulShots: Int = 0
    @Published var failedShots: Int = 0
    @Published var currentStatus: String = "Ready to start"
    @Published var angleClassification: String = ""
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isBodyPoseDetected: Bool = true {
        didSet {
            if !isBodyPoseDetected && oldValue == true {
                let now = Date()
                if lastNotInFrameSent == nil || now.timeIntervalSince(lastNotInFrameSent!) > notInFrameCooldown {
                    WatchConnectivityManager.shared.sendNotInFrameFeedback()
                    lastNotInFrameSent = now
                }
            } else if isBodyPoseDetected && oldValue == false {
                let now = Date()
                if lastBackInFrameSent == nil || now.timeIntervalSince(lastBackInFrameSent!) > notInFrameCooldown {
                    WatchConnectivityManager.shared.sendBackInFrameFeedback()
                    lastBackInFrameSent = now
                }
            }
        }
    }

    // --- Model Context ---
    var modelContext: ModelContext? = nil

    // --- Camera Capture Properties ---
    let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var playerStatusObserver: NSKeyValueObservation?
    let movieFileOutput = AVCaptureMovieFileOutput()
    private var recordingStartTime: CMTime?
    private let clipDuration: Double = 2.0 // Duration of clips for playback

    // --- Ball Tracking ---
    var frameCount = 0
    let frameSkip = 1 // Process every frame for best accuracy
    private let crossingCooldown = 30
    private var lastProcessedCrossing: Int = 0

    // --- Racquet & Impact Tracking ---
    private var previousActionLabel: String? = nil
    private var lastImpactPixelBuffer: CVPixelBuffer? = nil
    private var openRacquetTimestamp: Double? = nil
    private var closedRacquetTimestamp: Double? = nil
    private var optimalRacquetTimestamp: Double? = nil
    private let racquetAngleAnalysisCooldown: Double = 0.1 // Reduced cooldown for more responsive updates
    private var lastRacquetAngleAnalysisTime: Date? = nil

    // --- Not-in-frame Feedback ---
    private var lastNotInFrameSent: Date? = nil
    private var lastBackInFrameSent: Date? = nil
    private let notInFrameCooldown: Double = 2.0
    
    // MARK: - Services (Dependency Injection)
    /// ML Services for pose detection, angle classification, and object detection
    let swingPoseDetector: SwingPoseDetectionService
    let angleClassifier: AngleClassificationService
    let objectDetection: ObjectDetectionService
    
    /// Tracking and scoring services
    let ballTracker: BallTrackingService
    private let scoringService: ScoringService
    
    // MARK: - Computed Properties
    private var ballTrajectory: [BallPosition] {
        return ballTracker.ballTrajectory
    }

    // MARK: - Initialization
    override init() {
        // Initialize services
        self.swingPoseDetector = SwingPoseDetectionService()
        self.angleClassifier = AngleClassificationService()
        self.objectDetection = ObjectDetectionService()
        self.ballTracker = BallTrackingService()
        self.scoringService = ScoringService(ballTrackingService: ballTracker)
        
        super.init()
        setupCamera()
    }
    
    deinit {
        playerStatusObserver?.invalidate()
        displayLink?.invalidate()
        
        // Safely stop the capture session on a background queue to avoid crashes
        DispatchQueue.global(qos: .background).async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        Task {
            do {
                try await requestCameraPermission()
                try await configureCamera()
                await startCameraSession()
            } catch {
                await handleCameraSetupError(error)
            }
        }
    }
    
    private func requestCameraPermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw CameraSetupError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraSetupError.permissionDenied
        @unknown default:
            throw CameraSetupError.permissionDenied
        }
    }
    
    private func configureCamera() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraSetupError.deviceNotFound)
                    return
                }
                
                do {
                    self.captureSession.beginConfiguration()
                    
                    try self.setupVideoInput()
                    try self.setupVideoOutput()
                    try self.setupMovieOutput()
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
    
    private func setupVideoInput() throws {
        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back) else {
            throw CameraSetupError.deviceNotFound
        }
        
        // Configure device settings
        try configureVideoDevice(videoDevice)
        
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        
        guard captureSession.canAddInput(videoDeviceInput) else {
            throw CameraSetupError.cannotAddInput
        }
        
        captureSession.addInput(videoDeviceInput)
    }
    
    private func configureVideoDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        // Set optimal settings for tennis analysis
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        // Set frame rate for smooth video
        if let format = device.activeFormat.videoSupportedFrameRateRanges.first {
            let targetFrameRate = min(60.0, format.maxFrameRate)
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
        }
    }
    
    private func setupVideoOutput() throws {
        // Remove existing video outputs
        captureSession.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }.forEach {
            captureSession.removeOutput($0)
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        
        // Configure video output settings
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        // Create dedicated queue for video processing
        let videoQueue = DispatchQueue(label: "com.trytennis.video.processing", qos: .userInitiated)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        // Ensure frames are not dropped
        videoDataOutput.alwaysDiscardsLateVideoFrames = false
        
        guard captureSession.canAddOutput(videoDataOutput) else {
            throw CameraSetupError.cannotAddVideoOutput
        }
        
        captureSession.addOutput(videoDataOutput)
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoQueue
    }
    
    private func setupMovieOutput() throws {
        // Remove existing movie outputs
        captureSession.outputs.compactMap { $0 as? AVCaptureMovieFileOutput }.forEach {
            captureSession.removeOutput($0)
        }
        
        guard captureSession.canAddOutput(movieFileOutput) else {
            throw CameraSetupError.cannotAddMovieOutput
        }
        
        captureSession.addOutput(movieFileOutput)
    }
    
    private func configureSessionPreset() {
        // Try different presets in order of preference
        let preferredPresets: [AVCaptureSession.Preset] = [.high, .medium, .low]
        
        for preset in preferredPresets {
            if captureSession.canSetSessionPreset(preset) {
                captureSession.sessionPreset = preset
                break
            }
        }
    }
    
    private func startCameraSession() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                self.captureSession.startRunning()
                
                DispatchQueue.main.async {
                    self.isVideoReady = true
                    self.strokeClassification = "Camera ready - Tap to start racquet analysis"
                    continuation.resume()
                }
            }
        }
    }
    
    private func handleCameraSetupError(_ error: Error) async {
        await MainActor.run {
            let errorMessage: String
            if let cameraError = error as? CameraSetupError {
                errorMessage = cameraError.localizedDescription
            } else {
                errorMessage = "Camera setup failed: \(error.localizedDescription)"
            }
            
            self.strokeClassification = errorMessage
            self.isVideoReady = false
        }
    }
    
    // MARK: - Session Management
    
    private func stopSession() {
        guard captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    func restartCamera() {
        stopSession()
        setupCamera()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Recording Management

    private func startRecording() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                let tempURL = self.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).mov")
                self.recordingStartTime = CMTime.zero
                // Force video rotation angle to landscape right (0 degrees)
                if let connection = self.movieFileOutput.connection(with: .video) {
                    let angle: CGFloat = 0 // Always landscape right
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }
                // Start recording to a temporary file
                self.movieFileOutput.startRecording(to: tempURL, recordingDelegate: self)
            } else {
                DispatchQueue.main.async {
                    self.strokeClassification = "Photo access denied"
                    self.isProcessing = false // Stop processing if no access
                }
            }
        }
    }
    
    private func stopRecording() {
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        }
    }

    public func toggleProcessing() {
        isProcessing.toggle()
        if isProcessing {
            strokeClassification = "🎾 Detecting racquet and ball proximity..."
            frameCount = 0
            swingPoseDetector.resetPoseSequence()
            // Reset all tracking using the centralized method
            resetStatistics()
            openRacquetTimestamp = nil
            closedRacquetTimestamp = nil
            optimalRacquetTimestamp = nil
            // Start recording
            startRecording()
        } else {
            strokeClassification = "Paused"
            // Stop recording
            stopRecording()
            // Send session ended feedback to Apple Watch
            WatchConnectivityManager.shared.sendSessionEndedFeedback()
        }
    }

    // saveSessionData now accepts the local identifier for the video
    func saveSessionData(videoLocalIdentifier: String?) {
        guard let context = modelContext else { return }
        
        let newSession = Session(
            timestamp: Date(),
            totalAttempts: totalAttempts,
            successfulShots: successfulShots,
            failedShots: failedShots
        )
        newSession.videoLocalIdentifier = videoLocalIdentifier
        newSession.openRacquetTimestamp = self.openRacquetTimestamp
        newSession.closedRacquetTimestamp = self.closedRacquetTimestamp
        newSession.optimalRacquetTimestamp = self.optimalRacquetTimestamp
        
        context.insert(newSession)

    }
    
    // Method to inject ModelContext
    func setContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    private func checkRacquetBallProximityAndAnalyzeAngle(racquetPosition: CGRect, ballPosition: CGRect, pixelBuffer: CVPixelBuffer) {
        // Calculate distance between racquet and ball centers
        let racquetCenter = CGPoint(x: racquetPosition.midX, y: racquetPosition.midY)
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        
        let distance = sqrt(pow(racquetCenter.x - ballCenter.x, 2) + pow(racquetCenter.y - ballCenter.y, 2))
        
        // Define proximity threshold (adjust this value based on testing)
        let proximityThreshold: CGFloat = 0.22 // Was 0.15, now less strict
        
        // Check if racquet and ball are close enough
        if distance <= proximityThreshold {
            let currentTime = Date()
            if lastRacquetAngleAnalysisTime == nil ||
               currentTime.timeIntervalSince(lastRacquetAngleAnalysisTime!) >= racquetAngleAnalysisCooldown {

                DispatchQueue.main.async {
                    self.angleClassification = ""
                    self.currentStatus = "Analyzing racquet angle..."
                }
                angleClassifier.classify(on: pixelBuffer) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.angleClassification = result.angleResult
                        
                        // Optionally, use result.confidence for UI or logic
                        self?.currentStatus = "Angle classified: \(result.angleResult) (\(result.confidence))"
                    }
                }       // pindah ke AngleClassification
                lastRacquetAngleAnalysisTime = currentTime
            } else {
                //
            }
        } else {
            DispatchQueue.main.async {
                if !self.angleClassification.isEmpty {      // apa nih
                    self.angleClassification = ""
                    self.currentStatus = "Detecting racquet and ball proximity..."
                }
            }
        }
    }
    
    // MARK: - Scoring Methods
    
    private func processCrossingResult(_ result: NetCrossingResult) {
        // Prevent duplicate processing
        if frameCount - lastProcessedCrossing < crossingCooldown {
            return
        }
        
        lastProcessedCrossing = frameCount
        
        // Update scoring service with current frame count
        scoringService.setFrameCount(frameCount)
        
        DispatchQueue.main.async {
            switch result {
            case .success_over_net:
                self.scoringService.incrementSuccessful()
                
                // Update UI
                let stats = self.scoringService.getStatistics()
                self.successfulShots = stats.successful
                self.totalAttempts = stats.total
                
                // Send success feedback to watch
                WatchConnectivityManager.shared.sendImmediateShotFeedback(
                    angle: "Success",
                    isSuccessful: true
                )
                
            case .failed_hit_net, .failed_under_net:
                self.scoringService.incrementFailed()
                
                // Update UI
                let stats = self.scoringService.getStatistics()
                self.failedShots = stats.failed
                self.totalAttempts = stats.total
                
            case .uncertain:
                break
            }
        }
        
        // Reset tracking for next shot
        ballTracker.resetAllTracking()
    }

    /// Reset statistics and tracking
    func resetStatistics() {
        scoringService.resetStatistics()
        
        DispatchQueue.main.async {
            self.totalAttempts = 0
            self.successfulShots = 0
            self.failedShots = 0
            self.currentStatus = "Ready"
        }
        
        // Reset all tracking properties
        ballTracker.resetAllTracking()
        lastProcessedCrossing = 0
    }

}

// MARK: - Sendable
extension CameraViewModel: @unchecked Sendable {
    // This extension provides Sendable conformance
    // Using @unchecked Sendable because CameraViewModel manages its own thread safety
    // as an ObservableObject that inherits from NSObject
}
