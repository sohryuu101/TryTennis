import Foundation
import Vision
import CoreML

class SwingPoseDetector {
//    * setupSwingDetectionModel()
//    * setupPoseDetection()
//    * processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer)
//    * processPoseDetection(for:error:)
//    * performSwingDetection(currentPixelBuffer: CVPixelBuffer?) - (Should be modified to return a swing
//      classification, e.g., "Impact").
    private var swingDetectionModel: VNCoreMLModel?
    private var swingDetectionRequest: VNCoreMLRequest?
    
    private func setupSwingDetection() {
        do {
            let model = try SwingDetector(configuration: MLModelConfiguration()).model
            swingDetectionModel = try VNCoreMLModel(for: model)
            swingDetectionRequest = VNCoreMLRequest(model: swingDetectionModel!) { [weak self] (request, error) in
                self?.handleSwingDetectionCompleted(for: request, error: error)
            }
            racquetBallNetDetectionRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load AnotherRacquetDetect ML model: \(error)")
        }
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPoseRequest(completionHandler: { [weak self] (request, error) in
            self?.processPoseDetection(for: request, error: error)
        })
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
        guard let results = request.results as? [VNHumanBodyPoseObservation], let observation = results.first else {
            DispatchQueue.main.async {
                self.isBodyPoseDetected = false
            }
            return
        }
        DispatchQueue.main.async {
            self.isBodyPoseDetected = true
        }
        
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
    
    
}

