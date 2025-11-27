import Foundation
import CoreML
import Vision

/// Result from racquet/ball/net detection
struct RacquetBallNetDetectionResults {
    let pixelBuffer: CVPixelBuffer
    let detectedObjects: [DetectedObject]
    let racquetPosition: CGRect?
    let ballPosition: CGRect?
    let netPosition: CGRect?
}

/// Service for detecting racquet, ball, and net using ML
class ObjectDetectionService {
    // MARK: - Properties
    private var racquetBallNetDetectionModel: VNCoreMLModel?
    private var racquetBallNetDetectionRequest: VNCoreMLRequest?
    
    private var currentPixelBuffer: CVPixelBuffer?
    private var detectionCompletionHandler: ((RacquetBallNetDetectionResults) -> Void)?
    
    private var averageBallSize: CGFloat = 0.0
    private let minBallSizeRatio: CGFloat = 0.5
    private let maxBallSizeRatio: CGFloat = 2.0
    private let ballConfidenceThreshold: Float = 0.5
    private let netConfidenceThreshold: Float = 0.5
    private let racquetConfidenceThreshold: Float = 0.5
    
    // MARK: - Initialization
    init() {
        setupRacquetBallNetDetection()
    }
    
    // MARK: - Private Methods
    private func setupRacquetBallNetDetection() {
        do {
            let model = try RacquetBallNetDetect(configuration: MLModelConfiguration()).model
            racquetBallNetDetectionModel = try VNCoreMLModel(for: model)
            racquetBallNetDetectionRequest = VNCoreMLRequest(model: racquetBallNetDetectionModel!) { [weak self] (request, error) in
                self?.handleObjectDetectionCompleted(for: request, error: error)
            }
            racquetBallNetDetectionRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load RacquetBallNetDetect ML model: \(error)")
        }
    }
    
    private func handleObjectDetectionCompleted(for request: VNRequest, error: Error?) {
        guard let pixelBuffer = self.currentPixelBuffer,
            let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        var currentBallPosition: CGRect?
        var currentNetPosition: CGRect?
        var currentRacquetPosition: CGRect?
        var newDetectedObjects: [DetectedObject] = []
        
        for observation in results {
            guard let topLabelObservation = observation.labels.first else { continue }
            
            let boundingBox = observation.boundingBox
            let confidence = topLabelObservation.confidence
            let label = topLabelObservation.identifier
            
            if confidence > ballConfidenceThreshold && label == "ball" { 
                // Validate ball size if we have an average
                let ballArea = boundingBox.width * boundingBox.height
                let isValidSize = averageBallSize == 0.0 ||
                    (ballArea >= averageBallSize * minBallSizeRatio &&
                     ballArea <= averageBallSize * maxBallSizeRatio)
                
                if isValidSize {
                    currentBallPosition = boundingBox
                    updateAverageBallSize(ballArea)
                }
            } else if confidence > netConfidenceThreshold && label == "net" {
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
        
        let racquetBallNetResult = RacquetBallNetDetectionResults(
            pixelBuffer: pixelBuffer,
            detectedObjects: newDetectedObjects,
            racquetPosition: currentRacquetPosition,
            ballPosition: currentBallPosition,
            netPosition: currentNetPosition
        )
        
        detectionCompletionHandler?(racquetBallNetResult)
    }
    
    private func updateAverageBallSize(_ ballArea: CGFloat) {
        if averageBallSize == 0.0 {
            averageBallSize = ballArea
        } else {
            // Exponential moving average
            averageBallSize = averageBallSize * 0.9 + ballArea * 0.1
        }
    }
    
    // MARK: - Public Methods
    /// Detect racquet, ball, and net in a pixel buffer
    public func detectRacquetBallNet(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (RacquetBallNetDetectionResults) -> Void) {
        self.currentPixelBuffer = pixelBuffer
        self.detectionCompletionHandler = completionHandler
        
        guard let request = self.racquetBallNetDetectionRequest else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform racquet detection: \(error)")
        }
    }
}
