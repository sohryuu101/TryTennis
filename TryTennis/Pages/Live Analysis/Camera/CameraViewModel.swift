import AVFoundation
import CoreML
import Photos
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity

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
    let ballTracker = BallTracker()
    private var frameCount = 0
    private let frameSkip = 1 // Process every frame for best accuracy
    private let minConsecutiveFrames = 3 // Minimum frames to confirm ball detection

    // --- Net Detection & Crossing ---
    private var confirmedNetPosition: CGRect?
    private var currentNetFrameCount = 0
    private var ballSideHistory: [String] = [] // Track ball side over time
    private let sideHistoryLength = 5 // Consider last 5 positions
    private var crossingInProgress = false
    private var crossingStartFrame: Int = 0
    private var lastProcessedCrossing: Int = 0
    private let crossingCooldown = 30 // Frames to wait before processing another crossing
    private var netTopY: CGFloat = 0.0
    private var netBottomY: CGFloat = 1.0
    private var ballHeightAtCrossing: CGFloat = 0.0
    private var netPositionVariance: CGFloat = 0.0
    private var sessionNetPosition: CGRect? = nil // Persisted net position for the session

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
    private let notInFrameCooldown: TimeInterval = 3.0 // seconds
    
    override init() {
        super.init()
        setupCamera()
        ballTracker.delegate = self
    }
    
    deinit {
        playerStatusObserver?.invalidate()
        displayLink?.invalidate()
        stopSession()
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
            poseSequence.removeAll()
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
                analyzeRacquetAngle(pixelBuffer: pixelBuffer)       // pindah ke racquetheadangleclassification
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
    
    // MARK: - Enhanced Ball Tracking Methods
    
    private func analyzeNetCrossing(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        guard ballTrajectory.count >= 3 else { return .uncertain }
        
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let netCenterX = netPosition.midX
        
        // Determine which side of net the ball is on
        let currentSide = ballCenter.x < netCenterX ? "left" : "right"
        ballSideHistory.append(currentSide)
        
        // Keep only recent side history
        if ballSideHistory.count > sideHistoryLength {
            ballSideHistory.removeFirst()
        }
        
        // Check for crossing pattern (left to right typically for tennis)
        if ballSideHistory.count >= sideHistoryLength {
            let hasLeftSide = ballSideHistory.contains("left")
            let hasRightSide = ballSideHistory.contains("right")
            
            // Look for transition from left to right
            if hasLeftSide && hasRightSide && !crossingInProgress {
                return initiateCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
            }
        }
        
        // If crossing is in progress, continue monitoring
        if crossingInProgress {
            return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
        }
        
        return .uncertain
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
        ballSideHistory.removeAll()
        crossingInProgress = false
        velocityHistory.removeAll()
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
        ballTrajectory.removeAll()
        netPositions.removeAll()
        confirmedNetPosition = nil
        currentNetFrameCount = 0
        ballSideHistory.removeAll()
        crossingInProgress = false
        lastProcessedCrossing = 0
        ballVelocity = .zero
        lastBallVelocity = .zero
        velocityHistory.removeAll()
        lastBallState = .unknown
        consecutiveFramesWithBall = 0
        sessionNetPosition = nil
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessing, !isImpactProcessing else { return }
        
        frameCount += 1
        guard frameCount % frameSkip == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Pass pixelBuffer to pose detection
        processFrameForPoseDetection(pixelBuffer)
        
        // Process racquet detection
        if let racquetDetectionRequest = self.racquetDetectionRequest {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([racquetDetectionRequest])
            } catch {
                print("Failed to perform racquet detection: \(error)")
            }
        }
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
