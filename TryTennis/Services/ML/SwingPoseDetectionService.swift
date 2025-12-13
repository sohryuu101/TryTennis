import Foundation
import Vision
import CoreML

/// Result from swing detection
struct SwingDetectionResult {
    let strokeClassification: String
    let confidence: Double
}

/// Service for detecting tennis swing poses using ML
class SwingPoseDetectionService {
    // MARK: - Constants
    private enum Constants {
        static let sequenceLength = 30
        static let poseKeypointsCount = 18
        static let inputChannels = 3
        static let minConfidence: Float = 0.1
        static let inputShape: [NSNumber] = [30, 3, 18]
    }
    
    // MARK: - Properties
    private var swingDetector: SwingDetector?
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    
    private var currentPixelBuffer: CVPixelBuffer?
    private var swingDetectionCompletionHandler: ((SwingDetectionResult) -> Void)?
    
    public private(set) var poseSequence: [[Float]] = []
    
    // Cooldown management
    private var lastDetectionTime: Date?
    private let detectionCooldown: TimeInterval = 1.0
    
    // MARK: - Initialization
    init() {
        setupSwingDetection()
        setupPoseDetection()
    }
    
    // MARK: - Private Methods
    private func setupSwingDetection() {
        do {
            let config = MLModelConfiguration()
            let detector = try SwingDetector(configuration: config)
            swingDetector = detector
        } catch {
            print("Failed to load SwingDetector ML model: \(error)")
        }
    }
    
    private func setupPoseDetection() {
        self.poseRequest = VNDetectHumanBodyPoseRequest(completionHandler: { [weak self] (request, error) in
            self?.handlePoseDetectionCompleted(for: request, error: error)
        })
    }
    
    private func handlePoseDetectionCompleted(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNHumanBodyPoseObservation], let observation = results.first else { return }
        
        var poseData: [Float] = []
        
        let keypointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .neck
        ]
        
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            for jointName in keypointNames {
                if let point = recognizedPoints[jointName], Float(point.confidence) > Constants.minConfidence {
                    poseData.append(Float(point.location.x))
                    poseData.append(Float(point.location.y))
                    poseData.append(Float(point.confidence))
                } else {
                    poseData.append(0.0) // x
                    poseData.append(0.0) // y
                    poseData.append(0.0) // confidence
                }
            }
        } catch {
            print("Failed to extract pose keypoints: \(error)")
            return
        }
        
        poseSequence.append(poseData)
        
        if poseSequence.count > Constants.sequenceLength {
            poseSequence.removeFirst()
        }
        
        if poseSequence.count == Constants.sequenceLength {
            performSwingDetection()
        }
    }
    
    private func performSwingDetection() {
        guard let detector = swingDetector else { return }
        guard poseSequence.count == Constants.sequenceLength else { return }
        
        // Cooldown check
        if let lastTime = lastDetectionTime, Date().timeIntervalSince(lastTime) < detectionCooldown {
            return
        }
        
        // Deep copy sequence ...
        let currentSequence = poseSequence
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let inputArray = try MLMultiArray(shape: Constants.inputShape, dataType: .float32)
                
                // ... (filling input array) ...
                for (frameIndex, frameData) in currentSequence.enumerated() {
                    for keypointIndex in 0..<Constants.poseKeypointsCount {
                        let baseIndex = keypointIndex * Constants.inputChannels
                        guard baseIndex + 2 < frameData.count else { continue }
                        
                        let x = min(max(frameData[baseIndex], 0.0), 1.0)
                        let y = min(max(frameData[baseIndex + 1], 0.0), 1.0)
                        let confidence = min(max(frameData[baseIndex + 2], 0.0), 1.0)
                        
                        inputArray[[frameIndex, 0, keypointIndex] as [NSNumber]] = NSNumber(value: x)
                        inputArray[[frameIndex, 1, keypointIndex] as [NSNumber]] = NSNumber(value: y)
                        inputArray[[frameIndex, 2, keypointIndex] as [NSNumber]] = NSNumber(value: confidence)
                    }
                }
                
                let input = SwingDetectorInput(poses: inputArray)
                let output = try detector.prediction(input: input)
                
                let sortedProbabilities = output.labelProbabilities.sorted { $0.value > $1.value }
                if let topResult = sortedProbabilities.first, topResult.value > 0.7 { // only high confidence
                    let result = SwingDetectionResult(
                        strokeClassification: topResult.key,
                        confidence: topResult.value
                    )
                    
                    DispatchQueue.main.async {
                        self?.swingDetectionCompletionHandler?(result)
                        self?.lastDetectionTime = Date()
                        // Reset sequence to restart detection window
                        self?.resetPoseSequence() 
                    }
                }
            } catch {
                print("Failed to perform swing detection: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    /// Detect swing from a pixel buffer
    public func detectSwing(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (SwingDetectionResult) -> Void) {
        self.currentPixelBuffer = pixelBuffer
        self.swingDetectionCompletionHandler = completionHandler
        self.processFrameForPoseDetection(pixelBuffer)
    }
    
    /// Process a frame for pose detection
    public func processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer) {
        guard let poseRequest = self.poseRequest else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([poseRequest])
        } catch {
            print("Failed to perform pose detection request: \(error.localizedDescription)")
        }
    }
    
    /// Reset the pose sequence
    public func resetPoseSequence() {
        poseSequence.removeAll()
    }
}
