import SwiftUI
import AVFoundation
import Vision
import CoreML
import PhotosUI

class CameraService: NSObject, ObservableObject {
    @Published var strokeClassification: String = "Ready"
    @Published var isProcessing = false
    @Published var angleClassification: String = ""
    @Published var player: AVPlayer?
    @Published var isVideoReady = false

    // Camera capture properties
    let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    private var swingDetectionModel: SwingDetectorIteration_120?
    private var headAngleRequest: VNCoreMLRequest?
    private var poseRequest: VNDetectHumanBodyPoseRequest?

    private var isImpactProcessing = false
    private var frameCount = 0
    private let frameSkip = 1 // Process every frame for best accuracy
    
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

    override init() {
        super.init()
        setupCamera()
        setupSwingDetectionModel()
        setupHeadAngleRequest()
        setupPoseDetection()
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
        
        captureSession.commitConfiguration()
        
        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isVideoReady = true
                self?.strokeClassification = "Camera ready - Tap to start"
            }
        }
    }
    
    private func stopSession() {
        captureSession.stopRunning()
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
    
    public func toggleProcessing() {
        isProcessing.toggle()
        if isProcessing {
            strokeClassification = "Detecting poses..."
            frameCount = 0
            poseSequence.removeAll()
        } else {
            strokeClassification = "Paused"
        }
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
                    // Only trigger head angle when transitioning from impact to non-impact
                    if wasImpact && !isImpact {
                        if let pixelBuffer = self.lastImpactPixelBuffer {
                            self.analyzeRacquetAngle(pixelBuffer: pixelBuffer)
                            self.lastImpactPixelBuffer = nil // Reset after use
                        }
                    }
                    // Store the pixel buffer for the last impact frame
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
                self.resetAfterImpactAnalysis()
            }
        }
    }

    private func processHeadAngleClassification(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            defer { self.resetAfterImpactAnalysis() }
            
            guard let results = request.results as? [VNClassificationObservation] else {
                self.angleClassification = "Unable to classify racquet angle"
                return
            }
            
            if let topClassification = results.first {
                let confidence = Int(topClassification.confidence * 100)
                self.angleClassification = "Racquet angle: \(topClassification.identifier) (\(confidence)%)"
            } else {
                self.angleClassification = "No angle detected"
            }
        }
    }
    
    private func resetAfterImpactAnalysis() {
        // Show results for 1 second, then continue analyzing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.isProcessing {
                self.strokeClassification = "Detecting poses..."
                self.angleClassification = ""
            } else {
                self.strokeClassification = "Ready"
                self.angleClassification = ""
            }
            self.isImpactProcessing = false
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
    }
}
