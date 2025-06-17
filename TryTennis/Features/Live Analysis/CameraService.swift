import SwiftUI
import AVFoundation
import Vision
import CoreML
import PhotosUI
import SwiftData
import WatchConnectivity
import Photos

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
    
    // Ball tracking properties
    var lastBallPosition: CGRect?
    var lastNetPosition: CGRect?
    var currentRacquetPosition: CGRect? // Add racquet position tracking
    
    private var isBallCrossingNet = false
    private var lastBallState: BallState = .unknown
    private var consecutiveFramesWithBall = 0
    private let minConsecutiveFrames = 5 // Minimum frames to confirm ball detection
    
    // Add new properties for ball-net crossing detection
    private var netBox: CGRect? = nil
    private var netDetectionFrames = 0
    private let netDetectionMaxFrames = 10
    private var lastBallSide: String? = nil // "left" or "right"
    private var graceFrames = 0
    private let maxGraceFrames = 5
    private var pendingImpact: Bool = false
    private var pendingImpactTime: CMTime? = nil
    
    // Add properties for racquet-ball proximity detection
    private var lastRacquetAngleAnalysisTime: Date? = nil
    private var angleDismissTimer: Timer? = nil
    private let racquetAngleAnalysisCooldown: Double = 0.1 // Reduced cooldown for more responsive updates
    
    enum BallState {
        case unknown
        case approaching
        case crossing
        case passed
        case missed
    }
    
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
            strokeClassification = "Detecting racquet and ball proximity..."
            frameCount = 0
            poseSequence.removeAll()
            // Reset stats and clip timestamps when starting new session
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
        
        // Remove automatic racquet angle analysis - now triggered by racquet-ball proximity
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
                    
                    // Remove racquet angle analysis from swing detection - now handled by racquet-ball proximity
                    
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
        // Increment total attempts when a new impact is detected
        DispatchQueue.main.async {
            self.totalAttempts += 1
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
                // Remove automatic clearing - let it stay until next analysis
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
            
            if confidence > 0.5 { // Only consider detections with confidence > 0.5
                let detectedObject = DetectedObject(
                    label: label,
                    confidence: confidence,
                    boundingBox: boundingBox
                )
                newDetectedObjects.append(detectedObject)
                
                switch label {
                case "ball":
                    currentBallPosition = boundingBox
                case "net":
                    currentNetPosition = boundingBox
                case "racquet":
                    currentRacquetPosition = boundingBox
                default:
                    break
                }
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
        if netBox == nil, let netRect = currentNetPosition, netDetectionFrames < netDetectionMaxFrames { // Only try to set netBox if not already set
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
    
    private func processBallNetCrossing(ballPosition: CGRect) {
        guard let netBox = netBox else { return }
        let netLineX = netBox.minX // Use left edge of net as the crossing line
        let ballCenterX = ballPosition.midX
        
        graceFrames = 0 // reset grace period
        let side = ballCenterX < netLineX ? "left" : "right"
        
        if let lastSide = lastBallSide, lastSide == "left", side == "right" {
            // Ball crossed from left to right (player to net)
            // Check if the ball's Y is within the net's vertical bounds or below it
            if ballPosition.midY >= netBox.minY && ballPosition.midY <= netBox.maxY {
                // Ball hit the net (failed)
                handleFailedShot(reason: "hit the net")
            } else if ballPosition.midY < netBox.minY {
                // Ball went under the net (failed)
                handleFailedShot(reason: "went under the net")
            } else {
                // Ball passed over the net (success)
                handleSuccessfulShot()
            }
            lastBallSide = side
            pendingImpact = false
            pendingImpactTime = nil
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

    private func checkRacquetBallProximityAndAnalyzeAngle(racquetPosition: CGRect, ballPosition: CGRect, pixelBuffer: CVPixelBuffer) {
        // Calculate distance between racquet and ball centers
        let racquetCenter = CGPoint(x: racquetPosition.midX, y: racquetPosition.midY)
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)
        
        let distance = sqrt(pow(racquetCenter.x - ballCenter.x, 2) + pow(racquetCenter.y - ballCenter.y, 2))
        
        // Define proximity threshold (adjust this value based on testing)
        let proximityThreshold: CGFloat = 0.15 // Normalized distance threshold
        
        // Debug: Print distance for tuning
        print("Racquet-Ball distance: \(distance), threshold: \(proximityThreshold)")
        
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

    // Add method to reset statistics
    func resetStatistics() {
        DispatchQueue.main.async {
            self.totalAttempts = 0
            self.successfulShots = 0
            self.failedShots = 0
            self.currentStatus = "Ready"
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
