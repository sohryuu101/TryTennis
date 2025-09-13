import Foundation
import Vision
import CoreML

struct SwingDetectionResult {
    let strokeClassification: String
    let confidence: Double
}

class SwingPoseDetector {
    // --- Properties for the ML Models ---
    private var swingDetector: SwingDetector?
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    
    // --- Internal properties for a single detection pass ---
    private var currentPixelBuffer: CVPixelBuffer?
    private var swingDetectionCompletionHandler: ((SwingDetectionResult) -> Void)?
    
    // --- Internal properties for pose sequence logic ---
    public private(set) var poseSequence: [[Float]] = []
    private let sequenceLength = 30
    private let poseKeypoints = 18
    
    init() {
        setupSwingDetection()
        setupPoseDetection()
    }
    
    private func setupSwingDetection() {
        do {
            let detector = try SwingDetector(configuration: MLModelConfiguration())
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
    
    public func detectSwing(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (SwingDetectionResult) -> Void) {
        self.currentPixelBuffer = pixelBuffer
        self.swingDetectionCompletionHandler = completionHandler
        self.processFrameForPoseDetection(pixelBuffer)
    }
    
    public func processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer) {
        guard let poseRequest = self.poseRequest else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([poseRequest])
        } catch {
            print("Failed to perform pose detection request: \(error.localizedDescription)")
        }
    }
    
    private func handlePoseDetectionCompleted(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNHumanBodyPoseObservation], let observation = results.first else { return }
        
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
        
        // When we have enough frames, trigger swing detection directly
        if poseSequence.count == sequenceLength {
            performSwingDetection()
        }
    }
    
    private func performSwingDetection() {
        guard let detector = swingDetector else { return }
        
        // Only proceed if we have enough pose frames
        guard poseSequence.count == sequenceLength else { return }
        
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
            
            let input = SwingDetectorInput(poses: inputArray)
            let output = try detector.prediction(input: input)
            
            DispatchQueue.main.async {
                let sortedProbabilities = output.labelProbabilities.sorted { $0.value > $1.value }
                if let topResult = sortedProbabilities.first {
                    let confidence = topResult.value
                    let actionLabel = topResult.key
                    
                    let result = SwingDetectionResult(
                        strokeClassification: actionLabel,
                        confidence: confidence
                    )
                    
                    self.swingDetectionCompletionHandler?(result)
                }
            }
            
        } catch {
            print("Failed to perform swing detection: \(error)")
        }
    }
    
    public func resetPoseSequence() {
        poseSequence.removeAll()
    }
}
