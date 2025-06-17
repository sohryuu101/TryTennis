import AVFoundation
import CoreML
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity
import Photos

// Ball position tracking structure
struct BallPosition {
    let center: CGPoint
    let timestamp: CFTimeInterval
    let frame: Int
}

// Enhanced ball state enum
enum BallState {
    case unknown
    case detected
    case approaching_net
    case crossing_net
    case crossed_net
    case lost
}

// Net crossing result
enum NetCrossingResult {
    case success_over_net
    case failed_hit_net
    case failed_under_net
    case uncertain
}

class CameraService: NSObject, ObservableObject {
    @Published var strokeClassification: String = "Ready"
    @Published var isProcessing = false
    @Published var angleClassification: String = ""
    @Published var player: AVPlayer?
    @Published var isVideoReady = false
    
    // Add new published properties for tracking
    @Published var totalAttempts: Int = 0
    @Published var successfulShots: Int = 0
    @Published var failedShots: Int = 0
    @Published var currentStatus: String = "Ready to start"
    @Published var detectedObjects: [DetectedObject] = []
    
    // Add ModelContext property
    var modelContext: ModelContext? = nil

    // Camera capture properties
    let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    private var swingDetectionModel: SwingDetectorIteration_120?
    private var headAngleRequest: VNCoreMLRequest?
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var racquetDetectionModel: VNCoreMLModel?
    private var racquetDetectionRequest: VNCoreMLRequest?

    private var isImpactProcessing = false
    private var frameCount = 0
    private let frameSkip = 1 // Process every frame for best accuracy
    
    // Enhanced Ball tracking properties
    var lastBallPosition: CGRect?
    var lastNetPosition: CGRect?
    var currentRacquetPosition: CGRect?
    
    // Ball trajectory tracking
    private var ballTrajectory: [BallPosition] = []
    private let maxTrajectoryLength = 15 // Track last 15 positions for trajectory analysis
    private var ballVelocity: CGPoint = .zero
    private var lastBallVelocity: CGPoint = .zero
    
    // Enhanced net detection
    private var netPositions: [CGRect] = []
    private var confirmedNetPosition: CGRect?
    private var currentNetFrameCount = 0
    
    // Ball state tracking
    private var lastBallState: BallState = .unknown
    private var consecutiveFramesWithBall = 0
    private let minConsecutiveFrames = 3 // Minimum frames to confirm ball detection
    
    // Net crossing detection
    private var ballSideHistory: [String] = [] // Track ball side over time
    private let sideHistoryLength = 5 // Consider last 5 positions
    private var crossingInProgress = false
    private var crossingStartFrame: Int = 0
    private var lastProcessedCrossing: Int = 0
    private let crossingCooldown = 30 // Frames to wait before processing another crossing
    
    // Height analysis for net clearance
    private var netTopY: CGFloat = 0.0
    private var netBottomY: CGFloat = 1.0
    private var ballHeightAtCrossing: CGFloat = 0.0
    
    // Additional configuration for improved accuracy
    private let ballConfidenceThreshold: Float = 0.6  // Higher threshold for ball detection
    private let netConfidenceThreshold: Float = 0.7   // Higher threshold for net detection
    private let racquetConfidenceThreshold: Float = 0.5
    
    // Velocity smoothing for more stable trajectory analysis
    private var velocityHistory: [CGPoint] = []
    private let velocityHistoryLength = 5
    
    // Net position validation
    private var netPositionVariance: CGFloat = 0.0
    private let maxNetVariance: CGFloat = 0.05  // Maximum allowed variance in net position
    
    // Ball size filtering (helps filter out noise)
    private var averageBallSize: CGFloat = 0.0
    private let minBallSizeRatio: CGFloat = 0.5  // Minimum size relative to average
    private let maxBallSizeRatio: CGFloat = 2.0  // Maximum size relative to average
    
    // Pose sequence buffer for swing detection
    private var poseSequence: [[Float]] = []
    private let sequenceLength = 30 // 30 frames as expected by the model
    private let poseKeypoints = 18 // 18 keypoints as expected by the model
    
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var playerStatusObserver: NSKeyValueObservation?
    
    // Track previous action label for transition detection
    private var previousActionLabel: String? = nil
    // Store the last impact frame's pixel buffer
    private var lastImpactPixelBuffer: CVPixelBuffer? = nil
    // Add a property to store the current pixel buffer for each frame
    private var currentPixelBuffer: CVPixelBuffer? = nil
    
    // Video recording properties
    let movieFileOutput = AVCaptureMovieFileOutput()
    private var recordingStartTime: CMTime?
    // Storing timestamps as Doubles for persistence in SwiftData
    private var openRacquetTimestamp: Double? = nil
    private var closedRacquetTimestamp: Double? = nil
    private var optimalRacquetTimestamp: Double? = nil
    private let clipDuration: Double = 2.0 // Duration of clips for playback
    
    // Add properties for racquet-ball proximity detection
    private var lastRacquetAngleAnalysisTime: Date? = nil
    private var angleDismissTimer: Timer? = nil
    private let racquetAngleAnalysisCooldown: Double = 0.1 // Reduced cooldown for more responsive updates
    
    // Add at the top of the class:
    private var sessionNetPosition: CGRect? = nil // Persisted net position for the session
    private var angleResultHistory: [String] = [] // For robust angle detection
    private let angleResultHistoryLength = 5
    private let angleResultConsensus = 3 // Require 3/5 agreement
    private let angleConfidenceThreshold: Float = 0.7 // Only accept high-confidence angle results
    
    // --- Net crossing logic from robust branch ---
    private var netBox: CGRect? = nil
    private var netDetectionFrames = 0
    private let netDetectionMaxFrames = 10
    private var lastBallSide: String? = nil // "left" or "right"
    
    override init() {
        super.init()
        setupCamera()
        setupSwingDetectionModel()
        setupHeadAngleRequest()
        setupPoseDetection()
        setupRacquetDetection()
    }
    
    deinit {
        playerStatusObserver?.invalidate()
        displayLink?.invalidate()
        angleDismissTimer?.invalidate()
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
    
    private func setupSwingDetectionModel() {
        do {
            swingDetectionModel = try SwingDetectorIteration_120(configuration: MLModelConfiguration())
        } catch {
            print("Failed to load SwingDetection ML model: \(error)")
            DispatchQueue.main.async {
                self.strokeClassification = "Swing model loading failed"
            }
        }
    }

    private func setupHeadAngleRequest() {
        do {
            let model = try HeadAngleV2(configuration: MLModelConfiguration()).model
            let visionModel = try VNCoreMLModel(for: model)
            headAngleRequest = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                self?.processHeadAngleClassification(for: request, error: error)
            }
            headAngleRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load HeadAngleV2 ML model: \(error)")
            DispatchQueue.main.async {
                self.angleClassification = "Angle model loading failed"
            }
        }
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPoseRequest(completionHandler: { [weak self] (request, error) in
            self?.processPoseDetection(for: request, error: error)
        })
    }

    private func setupRacquetDetection() {
        do {
            let model = try AnotherRacquetDetect(configuration: MLModelConfiguration()).model
            racquetDetectionModel = try VNCoreMLModel(for: model)
            racquetDetectionRequest = VNCoreMLRequest(model: racquetDetectionModel!) { [weak self] (request, error) in
                self?.processRacquetDetection(for: request, error: error)
            }
            racquetDetectionRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load AnotherRacquetDetect ML model: \(error)")
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

    private func processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer) {
        self.currentPixelBuffer = pixelBuffer
        guard let poseRequest = self.poseRequest else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([poseRequest])
        } catch {
            print("Failed to perform pose detection request: \(error.localizedDescription)")
        }
    }
    
    private func processPoseDetection(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNHumanBodyPoseObservation] else {
            return
        }
        
        guard let observation = results.first else { return }
        
        // Extract pose keypoints
        var poseData: [Float] = []
        
        // Define the body keypoints in the expected order
        let keypointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .neck
        ]
        
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            for jointName in keypointNames {
                if let point = recognizedPoints[jointName], point.confidence > 0.1 {
                    // Use raw normalized coordinates as output by Vision
                    poseData.append(Float(point.location.x))
                    poseData.append(Float(point.location.y))
                    poseData.append(Float(point.confidence))
                } else {
                    // If keypoint not detected or low confidence, set to 0
                    poseData.append(0.0)
                    poseData.append(0.0)
                    poseData.append(0.0)
                }
            }
        } catch {
            print("Failed to extract pose keypoints: \(error)")
            return
        }
        
        // Add pose data to sequence
        poseSequence.append(poseData)
        
        // Keep only the last 30 frames
        if poseSequence.count > sequenceLength {
            poseSequence.removeFirst()
        }
        
        // When we have enough frames, perform swing detection
        if poseSequence.count == sequenceLength {
            // Pass the pixel buffer for this frame
            self.performSwingDetection(currentPixelBuffer: self.currentPixelBuffer)
        }
    }
    
    private func performSwingDetection(currentPixelBuffer: CVPixelBuffer?) {
        guard let model = swingDetectionModel else { return }
        do {
            // Create MLMultiArray with shape [30, 3, 18]
            let inputArray = try MLMultiArray(shape: [30, 3, 18], dataType: .float32)
            
            // Process each frame in the sequence
            for (frameIndex, frameData) in poseSequence.enumerated() {
                for keypointIndex in 0..<poseKeypoints {
                    let baseIndex = keypointIndex * 3
                    let x = min(max(frameData[baseIndex], 0.0), 1.0)
                    let y = min(max(frameData[baseIndex + 1], 0.0), 1.0)
                    let confidence = min(max(frameData[baseIndex + 2], 0.0), 1.0)
                    inputArray[[frameIndex, 0, keypointIndex] as [NSNumber]] = NSNumber(value: x)
                    inputArray[[frameIndex, 1, keypointIndex] as [NSNumber]] = NSNumber(value: y)
                    inputArray[[frameIndex, 2, keypointIndex] as [NSNumber]] = NSNumber(value: confidence)
                }
            }
            
            let input = SwingDetectorIteration_120Input(poses: inputArray)
            let output = try model.prediction(input: input)
            
            DispatchQueue.main.async {
                let sortedProbabilities = output.labelProbabilities.sorted { $0.value > $1.value }
                if let topResult = sortedProbabilities.first {
                    let confidence = topResult.value
                    let actionLabel = topResult.key
                    // Always show action and confidence for development
                    self.strokeClassification = "Action: \(actionLabel) (\(Int(confidence * 100))%)"
                    
                    let isImpact = actionLabel.lowercased().contains("impact") && confidence > 0.1
                    let wasImpact = (self.previousActionLabel?.lowercased().contains("impact") ?? false)
                    
                    // Handle impact detection
                    if isImpact && !wasImpact {
                        // New impact detected
                        self.handleNewImpact()
                    }
                    
                    // Store the pixel buffer for the last impact frame (keep for potential future use)
                    if isImpact, let pixelBuffer = currentPixelBuffer {
                        self.lastImpactPixelBuffer = pixelBuffer
                    }
                    self.previousActionLabel = actionLabel
                }
            }
            
        } catch {
            print("Failed to perform swing detection: \(error)")
            DispatchQueue.main.async {
                self.strokeClassification = "Swing detection failed"
            }
        }
    }

    private func handleNewImpact() {
        // No longer increment totalAttempts here; it is now counted on left-to-right crossing
        DispatchQueue.main.async {
            self.currentStatus = "Shot in progress..."
        }
    }

    private func analyzeRacquetAngle(pixelBuffer: CVPixelBuffer) {
        guard let headAngleRequest = self.headAngleRequest else {
            self.isImpactProcessing = false
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([headAngleRequest])
        } catch {
            print("Failed to perform head angle classification request: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.angleClassification = "Angle analysis failed"
            }
        }
    }

    private func processHeadAngleClassification(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation],
              let topResult = results.first else {
            return
        }
        
        DispatchQueue.main.async {
            // Immediately update the angle classification without delay
            self.angleClassification = topResult.identifier
            
            // Cancel any existing timer
            self.angleDismissTimer?.invalidate()
            
            // Start a new timer to dismiss the angle after 1.0 seconds
            self.angleDismissTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.angleClassification = ""
                    self.currentStatus = "Detecting racquet and ball proximity..."
                }
            }
            
            // Store the time for clip extraction as Double seconds
            let currentTime = self.movieFileOutput.recordedDuration.seconds
            switch topResult.identifier {
            case "Open":
                if self.openRacquetTimestamp == nil { // Only store the first occurrence
                    self.openRacquetTimestamp = currentTime
                }
            case "Closed":
                if self.closedRacquetTimestamp == nil { // Only store the first occurrence
                    self.closedRacquetTimestamp = currentTime
                }
            case "Perfect":
                if self.optimalRacquetTimestamp == nil { // Only store the first occurrence
                    self.optimalRacquetTimestamp = currentTime
                }
            default:
                break
            }
            
            // Send feedback to Apple Watch immediately
            let isSuccessful = topResult.identifier == "Perfect"
            WatchConnectivityManager.shared.sendImmediateShotFeedback(
                angle: topResult.identifier,
                isSuccessful: isSuccessful
            )
            
            // Update status to show the result briefly
            self.currentStatus = "Racquet angle: \(topResult.identifier)"
        }
        
        // In processHeadAngleClassification or wherever angle is classified:
        if let results = request.results as? [VNClassificationObservation], let topResult = results.first, topResult.confidence > angleConfidenceThreshold {
            angleResultHistory.append(topResult.identifier)
            if angleResultHistory.count > angleResultHistoryLength {
                angleResultHistory.removeFirst()
            }
            // Only update UI if consensus is reached
            let consensus = angleResultHistory.suffix(angleResultHistoryLength).filter { $0 == topResult.identifier }.count
            if consensus >= angleResultConsensus {
                DispatchQueue.main.async {
                    self.angleClassification = topResult.identifier
                }
            }
        }
    }
    
    private func processRacquetDetection(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        var currentBallPosition: CGRect?
        var currentNetPosition: CGRect?
        var currentRacquetPosition: CGRect?
        var newDetectedObjects: [DetectedObject] = []
        
        for observation in results {
            guard let topLabelObservation = observation.labels.first else { continue }
            
            let boundingBox = observation.boundingBox
            let confidence = topLabelObservation.confidence
            let label = topLabelObservation.identifier
            
            if confidence > ballConfidenceThreshold && label == "ball" { // Use higher threshold for ball
                // Validate ball size if we have an average
                let ballArea = boundingBox.width * boundingBox.height
                let isValidSize = averageBallSize == 0.0 ||
                    (ballArea >= averageBallSize * minBallSizeRatio &&
                     ballArea <= averageBallSize * maxBallSizeRatio)
                
                if isValidSize {
                    currentBallPosition = boundingBox
                    updateAverageBallSize(ballArea)
                }
            } else if confidence > netConfidenceThreshold && label == "net" { // Use higher threshold for net
                currentNetPosition = boundingBox
            } else if confidence > racquetConfidenceThreshold && label == "racquet" {
                currentRacquetPosition = boundingBox
            }
            
            // Only add high-confidence detections to UI
            if (label == "ball" && confidence > ballConfidenceThreshold) ||
               (label == "net" && confidence > netConfidenceThreshold) ||
               (label == "racquet" && confidence > racquetConfidenceThreshold) {
                let detectedObject = DetectedObject(
                    label: label,
                    confidence: confidence,
                    boundingBox: boundingBox
                )
                newDetectedObjects.append(detectedObject)
            }
        }
        
        // Update detected objects for UI
        DispatchQueue.main.async {
            self.detectedObjects = newDetectedObjects
        }
        
        // Update racquet position
        self.currentRacquetPosition = currentRacquetPosition
        
        // Check for racquet-ball proximity and trigger HeadAngleV2
        if let racquetPosition = currentRacquetPosition,
           let ballPosition = currentBallPosition,
           let currentPixelBuffer = self.currentPixelBuffer {
            checkRacquetBallProximityAndAnalyzeAngle(
                racquetPosition: racquetPosition,
                ballPosition: ballPosition,
                pixelBuffer: currentPixelBuffer
            )
        }
        
        // Net detection only in the first N frames
        if netBox == nil, let netRect = currentNetPosition, netDetectionFrames < netDetectionMaxFrames {
            netBox = netRect
            netDetectionFrames += 1
        }
        // Process ball-net crossing
        if let ballPosition = currentBallPosition {
            processBallNetCrossing(ballPosition: ballPosition)
        }
        
        // Store positions for next frame (for ball-net crossing logic only, not for drawing)
        lastBallPosition = currentBallPosition
        lastNetPosition = currentNetPosition
    }
    
    // MARK: - Enhanced Ball Tracking Methods
    
    // Helper method to update average ball size for filtering
    private func updateAverageBallSize(_ ballArea: CGFloat) {
        if averageBallSize == 0.0 {
            averageBallSize = ballArea
        } else {
            // Exponential moving average
            averageBallSize = averageBallSize * 0.9 + ballArea * 0.1
        }
    }
    
    // Enhanced velocity calculation with smoothing
    private func calculateSmoothedVelocity() {
        guard ballTrajectory.count >= 2 else { return }
        
        let current = ballTrajectory.last!
        let previous = ballTrajectory[ballTrajectory.count - 2]
        
        let timeDiff = current.timestamp - previous.timestamp
        if timeDiff > 0 {
            let instantVelocity = CGPoint(
                x: (current.center.x - previous.center.x) / CGFloat(timeDiff),
                y: (current.center.y - previous.center.y) / CGFloat(timeDiff)
            )
            
            velocityHistory.append(instantVelocity)
            if velocityHistory.count > velocityHistoryLength {
                velocityHistory.removeFirst()
            }
            
            // Calculate smoothed velocity
            if !velocityHistory.isEmpty {
                let avgVelX = velocityHistory.map { $0.x }.reduce(0, +) / CGFloat(velocityHistory.count)
                let avgVelY = velocityHistory.map { $0.y }.reduce(0, +) / CGFloat(velocityHistory.count)
                
                lastBallVelocity = ballVelocity
                ballVelocity = CGPoint(x: avgVelX, y: avgVelY)
            }
        }
    }
    
    // Validate net position consistency
    private func validateNetPosition(_ netRect: CGRect) -> Bool {
        if netPositions.isEmpty {
            return true
        }
        
        // Check if new position is consistent with previous detections
        let recentPositions = netPositions.suffix(5)
        let avgX = recentPositions.map { $0.midX }.reduce(0, +) / CGFloat(recentPositions.count)
        let avgY = recentPositions.map { $0.midY }.reduce(0, +) / CGFloat(recentPositions.count)
        
        let variance = sqrt(pow(netRect.midX - avgX, 2) + pow(netRect.midY - avgY, 2))
        return variance < maxNetVariance
    }
    
    private func calculateStableNetPosition() -> CGRect? {
        guard !netPositions.isEmpty else { return nil }
        
        // Calculate average position for stability
        let avgX = netPositions.map { $0.midX }.reduce(0, +) / CGFloat(netPositions.count)
        let avgY = netPositions.map { $0.midY }.reduce(0, +) / CGFloat(netPositions.count)
        let avgWidth = netPositions.map { $0.width }.reduce(0, +) / CGFloat(netPositions.count)
        let avgHeight = netPositions.map { $0.height }.reduce(0, +) / CGFloat(netPositions.count)
        
        return CGRect(
            x: avgX - avgWidth/2,
            y: avgY - avgHeight/2,
            width: avgWidth,
            height: avgHeight
        )
    }
    
    private func updateBallTrajectory(ballPosition: CGRect, frameCount: Int) {
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let ballPos = BallPosition(center: ballCenter, timestamp: timestamp, frame: frameCount)
        ballTrajectory.append(ballPos)
        
        // Keep only recent trajectory points
        if ballTrajectory.count > maxTrajectoryLength {
            ballTrajectory.removeFirst()
        }
        
        // Calculate smoothed velocity
        calculateSmoothedVelocity()
        
        consecutiveFramesWithBall += 1
        
        // Update ball state based on trajectory
        updateBallState(ballCenter: ballCenter)
    }
    
    private func updateBallState(ballCenter: CGPoint) {
        guard let netPos = confirmedNetPosition else {
            lastBallState = .detected
            return
        }
        
        let distanceToNet = abs(ballCenter.x - netPos.midX)
        let isMovingTowardNet = ballVelocity.x > 0 // Assuming net is on the right
        
        if distanceToNet < 0.15 && isMovingTowardNet {
            lastBallState = .approaching_net
        } else if distanceToNet < 0.05 {
            lastBallState = .crossing_net
        } else if ballCenter.x > netPos.midX + 0.1 {
            lastBallState = .crossed_net
        } else {
            lastBallState = .detected
        }
    }
    
    private func handleBallLost() {
        consecutiveFramesWithBall = 0
        
        // If ball was lost during crossing, try to infer result from trajectory
        if crossingInProgress && ballTrajectory.count >= 3 {
            let result = inferCrossingFromLostBall()
            if result != .uncertain {
                processCrossingResult(result)
            }
        }
        
        // Clear old trajectory if ball has been lost for too long
        if ballTrajectory.count > 0 &&
           CFAbsoluteTimeGetCurrent() - ballTrajectory.last!.timestamp > 1.0 {
            ballTrajectory.removeAll()
            ballSideHistory.removeAll()
            crossingInProgress = false
        }
    }
    
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
    
    private func initiateCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        crossingInProgress = true
        crossingStartFrame = frameCount
        ballHeightAtCrossing = ballPosition.midY
        
        print("🎾 Initiated net crossing analysis at frame \(frameCount)")
        print("📊 Ball height: \(ballHeightAtCrossing), Net top: \(netTopY), Net bottom: \(netBottomY)")
        print("⚡ Ball velocity: \(ballVelocity)")
        
        DispatchQueue.main.async {
            self.currentStatus = "Analyzing ball crossing..."
        }
        
        return continueCrossingAnalysis(ballPosition: ballPosition, netPosition: netPosition)
    }
    
    private func continueCrossingAnalysis(ballPosition: CGRect, netPosition: CGRect) -> NetCrossingResult {
        let ballCenterX = ballPosition.midX
        let netCenterX = netPosition.midX
        
        // Check if ball has clearly crossed to the right side
        if ballCenterX > netCenterX + (netPosition.width * 0.3) {
            crossingInProgress = false
            
            // Analyze trajectory at crossing point
            let crossingHeight = estimateCrossingHeight()
            
            // Determine result based on height relative to net
            let netMargin: CGFloat = 0.01 // Tighter margin
            if crossingHeight < netTopY - netMargin && validateSuccessfulTrajectory() {
                return .success_over_net
            } else if crossingHeight > netBottomY + 0.02 {  // Ball went clearly below net
                return .failed_under_net
            } else if crossingHeight >= netTopY - 0.02 && crossingHeight <= netBottomY + 0.02 {
                // Ball height is within net bounds - likely hit the net
                return .failed_hit_net
            }
        }
        
        return .uncertain
    }
    
    private func estimateCrossingHeight() -> CGFloat {
        guard ballTrajectory.count >= 3 else { return ballHeightAtCrossing }
        
        // Find the trajectory points closest to the net crossing
        guard let netPos = confirmedNetPosition else { return ballHeightAtCrossing }
        let netX = netPos.midX
        
        var closestPoints: [BallPosition] = []
        for position in ballTrajectory.suffix(8) {  // Look at recent positions
            if abs(position.center.x - netX) < 0.1 {  // Points near the net
                closestPoints.append(position)
            }
        }
        
        if !closestPoints.isEmpty {
            // Average the heights of points near the net
            let avgHeight = closestPoints.map { $0.center.y }.reduce(0, +) / CGFloat(closestPoints.count)
            return avgHeight
        }
        
        // Fallback: interpolate based on trajectory
        if ballTrajectory.count >= 2 {
            let recent = ballTrajectory.suffix(2)
            let p1 = recent.first!
            let p2 = recent.last!
            
            // Linear interpolation to estimate height at net X position
            if p2.center.x != p1.center.x {
                let slope = (p2.center.y - p1.center.y) / (p2.center.x - p1.center.x)
                let interpolatedY = p1.center.y + slope * (netX - p1.center.x)
                return interpolatedY
            }
        }
        
        return ballHeightAtCrossing
    }
    
    private func inferCrossingFromLostBall() -> NetCrossingResult {
        guard let lastPosition = ballTrajectory.last,
              let netPos = confirmedNetPosition else { return .uncertain }
        
        // If ball was moving toward net and then lost, infer based on last known trajectory
        if ballVelocity.x > 0 && lastPosition.center.x > netPos.midX {
            // Ball was crossing when lost
            let estimatedHeight = estimateCrossingHeight()
            
            if estimatedHeight < netTopY - 0.02 {
                return .success_over_net
            } else if estimatedHeight > netBottomY + 0.02 {
                return .failed_under_net
            } else {
                return .failed_hit_net
            }
        }
        
        return .uncertain
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

    private func checkRacquetBallProximityAndAnalyzeAngle(racquetPosition: CGRect, ballPosition: CGRect, pixelBuffer: CVPixelBuffer) {
        // Calculate distance between racquet and ball centers
        let racquetCenter = CGPoint(x: racquetPosition.midX, y: racquetPosition.midY)
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        
        let distance = sqrt(pow(racquetCenter.x - ballCenter.x, 2) + pow(racquetCenter.y - ballCenter.y, 2))
        
        // Define proximity threshold (adjust this value based on testing)
        let proximityThreshold: CGFloat = 0.15 // Normalized distance threshold
        
        // Check if racquet and ball are close enough
        if distance <= proximityThreshold {
            // Check cooldown to avoid too frequent analysis
            let currentTime = Date()
            if lastRacquetAngleAnalysisTime == nil ||
               currentTime.timeIntervalSince(lastRacquetAngleAnalysisTime!) >= racquetAngleAnalysisCooldown {
                
                print("Triggering HeadAngleV2 analysis - racquet and ball are close")
                
                // Clear previous angle classification immediately to show new analysis is starting
                DispatchQueue.main.async {
                    self.angleClassification = ""
                    self.currentStatus = "Analyzing racquet angle..."
                }
                
                // Trigger HeadAngleV2 analysis
                analyzeRacquetAngle(pixelBuffer: pixelBuffer)
                lastRacquetAngleAnalysisTime = currentTime
                
            } else {
                print("Skipping analysis - cooldown active")
            }
        } else {
            // Clear angle classification when racquet and ball are not close
            // This prevents stale results from persisting
            DispatchQueue.main.async {
                if !self.angleClassification.isEmpty {
                    self.angleClassification = ""
                    self.currentStatus = "Detecting racquet and ball proximity..."
                }
            }
        }
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
        averageBallSize = 0.0
        lastBallState = .unknown
        consecutiveFramesWithBall = 0
        sessionNetPosition = nil
        angleResultHistory.removeAll()
    }

    // Validate that the ball's trajectory is smooth and consistent before and after net crossing
    private func validateSuccessfulTrajectory() -> Bool {
        // Require at least 5 trajectory points
        guard ballTrajectory.count >= 5 else { return false }
        // Check that the ball is moving mostly in the positive X direction (rightwards)
        let recent = ballTrajectory.suffix(5)
        let dxs = recent.dropFirst().enumerated().map { i, pos in
            pos.center.x - recent[i].center.x
        }
        let avgDx = dxs.reduce(0, +) / CGFloat(dxs.count)
        // Require average dx to be positive and above a small threshold
        guard avgDx > 0.005 else { return false }
        // Check that the Y values do not fluctuate wildly (no big bounces or drops)
        let dys = recent.dropFirst().enumerated().map { i, pos in
            abs(pos.center.y - recent[i].center.y)
        }
        let maxDy = dys.max() ?? 0
        // Require max dy to be within a reasonable range
        return maxDy < 0.08
    }

    private func processBallNetCrossing(ballPosition: CGRect) {
        guard let netBox = netBox else { return }
        let netLineX = netBox.minX // Use left edge of net as the crossing line
        let ballCenterX = ballPosition.midX
        let side = ballCenterX < netLineX ? "left" : "right"
        if let lastSide = lastBallSide, lastSide == "left", side == "right" {
            // Ball crossed from left to right (player to net)
            DispatchQueue.main.async {
                self.totalAttempts += 1
            }
            if ballPosition.midY >= netBox.minY && ballPosition.midY <= netBox.maxY {
                handleFailedShot(reason: "hit the net")
            } else if ballPosition.midY < netBox.minY {
                handleFailedShot(reason: "went under the net")
            } else {
                handleSuccessfulShot()
            }
            lastBallSide = side
            return
        }
        lastBallSide = side
    }

    private func handleSuccessfulShot() {
        DispatchQueue.main.async {
            self.successfulShots += 1
            self.currentStatus = "Shot successful!"
        }
    }

    private func handleFailedShot(reason: String) {
        DispatchQueue.main.async {
            self.failedShots += 1
            self.currentStatus = "Shot failed - \(reason)"
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessing, !isImpactProcessing else { return }
        
        frameCount += 1
        // Skip frames for better performance
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
extension CameraService: AVCaptureFileOutputRecordingDelegate {
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
            DispatchQueue.main.async { // Ensure UI updates and SwiftData operations are on main thread
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

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
