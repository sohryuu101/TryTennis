import Foundation
import AVFoundation
import CoreML
import Photos
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity

class CameraViewModel: NSObject, ObservableObject, BallTrackerDelegate {
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
    private var frameCount = 0
    private let frameSkip = 1 // Process every frame for best accuracy
    private let minConsecutiveFrames = 3 // Minimum frames to confirm ball detection
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

    // --- Access ball/net/crossing state via ballTracker ---
    // Example usage:
    // var confirmedNetPosition: CGRect? { ballTracker.confirmedNetPosition }
    // var ballSideHistory: [String] { ballTracker.ballSideHistory }
    // var crossingInProgress: Bool { ballTracker.crossingInProgress }
    // var netTopY: CGFloat { ... } // If needed, add to BallTracker
    // var netBottomY: CGFloat { ... } // If needed, add to BallTracker
    // var ballHeightAtCrossing: CGFloat { ... } // If needed, add to BallTracker
    
    // --- ML Utility Properties ---
    private let swingPoseDetector = SwingPoseDetector()
    private let angleClassifier = AngleClassifier()
    private let ballTracker = BallTracker()
    private let objectDetection = RacquetBallNetDetection()
    
    private var ballTrajectory: [BallPosition] {
        return ballTracker.ballTrajectory
    }

    override init() {
        super.init()
        setupCamera()
        ballTracker.delegate = self
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

    private func setupCamera() {
        captureSession.beginConfiguration()
        
        // Set up video quality
        captureSession.sessionPreset = .high
        
        // Get the back camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back) else {
            print("Could not find a back camera")
            return
        }
        
        // Create video input
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Could not create video device input")
            return
        }
        
        guard captureSession.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        
        // Set up video output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutput", qos: .userInitiated))
        
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("Could not add video data output to the session")
            return
        }
        
        captureSession.addOutput(videoDataOutput)
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
        
        // Add movieFileOutput to session
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
        }
        
        captureSession.commitConfiguration()
        
        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isVideoReady = true
                self?.strokeClassification = "Camera ready - Tap to start racquet analysis"
            }
        }
    }
    
    private func stopSession() {
        captureSession.stopRunning()
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
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
                print("Photo library access denied. Cannot record video.")
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
    private func saveSessionData(videoLocalIdentifier: String?) {
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
        
        print("Session saved with video local identifier and timestamps.")
    }
    
    // Method to inject ModelContext
    func setContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private func handleNewImpact() {
        // No longer increment totalAttempts here; it is now counted on left-to-right crossing
        DispatchQueue.main.async {
            self.currentStatus = "Shot in progress..."
        }
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
                print("[DEBUG] Triggering HeadAngleV2 analysis - racquet and ball are close (distance: \(distance))")
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
                print("[DEBUG] Skipping analysis - cooldown active")
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
    
    func ballTracker(_ tracker: BallTracker, didProcessCrossingResult result: NetCrossingResult) {
        processCrossingResult(result)
    }
    
    private func processCrossingResult(_ result: NetCrossingResult) {
        // Prevent duplicate processing
        if frameCount - lastProcessedCrossing < crossingCooldown {
            return
        }
        
        lastProcessedCrossing = frameCount
        
        DispatchQueue.main.async {
            switch result {
            case .success_over_net:
                self.successfulShots += 1
                self.currentStatus = "✅ Shot successful! Ball cleared the net"
                print("🎉 SUCCESSFUL SHOT: Ball cleared net at frame \(self.frameCount)")
                
                // Send success feedback to watch
                WatchConnectivityManager.shared.sendImmediateShotFeedback(
                    angle: "Success",
                    isSuccessful: true
                )
                
            case .failed_hit_net:
                self.failedShots += 1
                self.currentStatus = "❌ Shot failed - ball hit the net"
                print("💥 FAILED SHOT: Ball hit net at frame \(self.frameCount)")
                
            case .failed_under_net:
                self.failedShots += 1
                self.currentStatus = "❌ Shot failed - ball went under the net"
                print("⬇️ FAILED SHOT: Ball went under net at frame \(self.frameCount)")
                
            case .uncertain:
                self.currentStatus = "🤔 Uncertain crossing result"
                break
            }
            
            // Auto-hide status after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.currentStatus.contains("successful") || self.currentStatus.contains("failed") {
                    self.currentStatus = "Ready for next shot"
                }
            }
        }
        
        // Reset tracking for next shot
        ballTracker.resetAllTracking()
    }

    // Add method to reset statistics and tracking
    func resetStatistics() {
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

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessing else { return }
        
        frameCount += 1
        guard frameCount % frameSkip == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Pass pixelBuffer to pose detection
        swingPoseDetector.processFrameForPoseDetection(pixelBuffer)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            // Save session data without video if recording failed
            DispatchQueue.main.async { [weak self] in
                self?.saveSessionData(videoLocalIdentifier: nil)
            }
            try? FileManager.default.removeItem(at: outputFileURL) // Clean up temporary file
            return
        }
        
        // Save the recorded video to Photos library
        var localIdentifier: String? = nil
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            localIdentifier = creationRequest?.placeholderForCreatedAsset?.localIdentifier
        }) { [weak self] saved, error in
            DispatchQueue.main.async {
                if saved {
                    self?.saveSessionData(videoLocalIdentifier: localIdentifier)
                } else {
                    print("Error saving video to Photos library: \(error?.localizedDescription ?? "unknown error")")
                    self?.saveSessionData(videoLocalIdentifier: nil)
                }
                // Delete the temporary video file after it's been handled by Photos
                try? FileManager.default.removeItem(at: outputFileURL)
            }
        }
    }
}
