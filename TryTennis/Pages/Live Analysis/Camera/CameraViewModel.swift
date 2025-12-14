import Foundation
import AVFoundation
import CoreML
import Photos
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity

/// ViewModel for Camera and Live Analysis feature
/// De-coupled from low-level AVFoundation logic by using CameraService
class CameraViewModel: NSObject, ObservableObject {
    
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

    // --- Services ---
    private let cameraService = CameraService()
    
    // Expose session for View consumption (if needed for PreviewView)
    var captureSession: AVCaptureSession {
        return cameraService.session
    }

    // --- Recording State ---
    private let clipDuration: Double = 2.0
    
    // --- Ball Tracking ---
    var frameCount = 0
    let frameSkip = 1
    private let crossingCooldown = 30
    private var lastProcessedCrossing: Int = 0
    
    // --- Racquet & Impact Tracking ---
    private var previousActionLabel: String? = nil
    private var lastImpactPixelBuffer: CVPixelBuffer? = nil
    private var openRacquetTimestamp: Double? = nil
    private var closedRacquetTimestamp: Double? = nil
    private var optimalRacquetTimestamp: Double? = nil
    private let racquetAngleAnalysisCooldown: Double = 0.1
    private var lastRacquetAngleAnalysisTime: Date? = nil

    // --- Not-in-frame Feedback ---
    private var lastNotInFrameSent: Date? = nil
    private var lastBackInFrameSent: Date? = nil
    private let notInFrameCooldown: Double = 2.0
    
    // MARK: - Services (Dependency Injection)
    let swingPoseDetector: SwingPoseDetectionService
    let angleClassifier: AngleClassificationService
    let objectDetection: ObjectDetectionService
    let ballTracker: BallTrackingService
    private let scoringService: ScoringService
    
    // MARK: - Computed Properties
    private var ballTrajectory: [BallPosition] {
        return ballTracker.ballTrajectory
    }

    // MARK: - Initialization
    override init() {
        self.swingPoseDetector = SwingPoseDetectionService()
        self.angleClassifier = AngleClassificationService()
        self.objectDetection = ObjectDetectionService()
        self.ballTracker = BallTrackingService()
        self.scoringService = ScoringService(ballTrackingService: ballTracker)
        
        super.init()
        
        // Setup Camera Service Delegate
        cameraService.delegate = self
        setupCamera()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        Task {
            do {
                try await cameraService.setupCamera()
                await cameraService.startSession()
                
                await MainActor.run {
                    self.isVideoReady = true
                    self.strokeClassification = "Camera ready - Tap to start racquet analysis"
                }
            } catch {
                await MainActor.run {
                    self.strokeClassification = "Camera setup failed: \(error.localizedDescription)"
                    self.isVideoReady = false
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    func restartCamera() {
        cameraService.stopSession()
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
                // Clean up any existing file at this path (unlikely with UUID but safe)
                try? FileManager.default.removeItem(at: tempURL)
                
                self.frameSkipReset() // Reset tracking counters
                self.cameraService.startRecording(to: tempURL)
            } else {
                DispatchQueue.main.async {
                    self.strokeClassification = "Photo access denied"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func stopRecording() {
        cameraService.stopRecording()
    }

    public func toggleProcessing() {
        isProcessing.toggle()
        if isProcessing {
            strokeClassification = "🎾 Detecting racquet and ball proximity..."
            resetProcessingState()
            startRecording()
        } else {
            strokeClassification = "Paused"
            stopRecording()
            WatchConnectivityManager.shared.sendSessionEndedFeedback()
        }
    }
    
    private func resetProcessingState() {
        frameCount = 0
        swingPoseDetector.resetPoseSequence()
        resetStatistics()
        openRacquetTimestamp = nil
        closedRacquetTimestamp = nil
        optimalRacquetTimestamp = nil
    }
    
    // Convenience for reset
    private func frameSkipReset() {
        // Any logic needed when recording effectively starts
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
        let racquetCenter = CGPoint(x: racquetPosition.midX, y: racquetPosition.midY)
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        
        let distance = sqrt(pow(racquetCenter.x - ballCenter.x, 2) + pow(racquetCenter.y - ballCenter.y, 2))
        let proximityThreshold: CGFloat = 0.22
        
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
                        self?.currentStatus = "Angle classified: \(result.angleResult) (\(result.confidence))"
                    }
                }
                lastRacquetAngleAnalysisTime = currentTime
            }
        } else {
            DispatchQueue.main.async {
                if !self.angleClassification.isEmpty {
                    self.angleClassification = ""
                    self.currentStatus = "Detecting racquet and ball proximity..."
                }
            }
        }
    }
    
    // MARK: - Scoring Methods
    
    private func processCrossingResult(_ result: NetCrossingResult) {
        if frameCount - lastProcessedCrossing < crossingCooldown {
            return
        }
        
        lastProcessedCrossing = frameCount
        scoringService.setFrameCount(frameCount)
        
        DispatchQueue.main.async {
            switch result {
            case .success_over_net:
                self.scoringService.incrementSuccessful()
                let stats = self.scoringService.getStatistics()
                self.successfulShots = stats.successful
                self.totalAttempts = stats.total
                
                WatchConnectivityManager.shared.sendImmediateShotFeedback(
                    angle: "Success",
                    isSuccessful: true
                )
                
            case .failed_hit_net, .failed_under_net:
                self.scoringService.incrementFailed()
                let stats = self.scoringService.getStatistics()
                self.failedShots = stats.failed
                self.totalAttempts = stats.total
                
            case .uncertain:
                break
            }
        }
        
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
        
        ballTracker.resetAllTracking()
        lastProcessedCrossing = 0
    }
}

// MARK: - CameraServiceDelegate
extension CameraViewModel: CameraServiceDelegate {
    func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer) {
        guard isProcessing else { return }
        
        frameCount += 1
        guard frameCount % frameSkip == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Pass pixelBuffer to pose detection
        swingPoseDetector.processFrameForPoseDetection(pixelBuffer)
        
        // NOTE: Previous implementation only called pose detection.
        // If Object Detection or Ball Tracking needs to run, it should be called here or triggered by Pose Detection events.
        // Assuming SwingPoseDetectionService might trigger other things or we need to add back the other detection calls if they were missing in the previous file snapshot?
        // Checking the previous file...
        // The extension CameraViewModel+SampleBufferDelegate ONLY called `swingPoseDetector.processFrameForPoseDetection(pixelBuffer)`.
        // So I will replicate that EXACTLY to avoid introducing bugs.
    }
    
    func cameraService(_ service: CameraService, didFinishRecordingTo outputFileURL: URL, error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.saveSessionData(videoLocalIdentifier: nil)
            }
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        
        // Save to Photos
        var localIdentifier: String? = nil
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            localIdentifier = creationRequest?.placeholderForCreatedAsset?.localIdentifier
        }) { [weak self] saved, error in
            DispatchQueue.main.async {
                if saved {
                    self?.saveSessionData(videoLocalIdentifier: localIdentifier)
                } else {
                    print("Error saving video to Photos: \(error?.localizedDescription ?? "unknown")")
                    self?.saveSessionData(videoLocalIdentifier: nil)
                }
                try? FileManager.default.removeItem(at: outputFileURL)
            }
        }
    }
    
    func cameraService(_ service: CameraService, didEncounterError error: Error) {
        Task { @MainActor in
            self.currentStatus = "Camera Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sendable
extension CameraViewModel: @unchecked Sendable { }
