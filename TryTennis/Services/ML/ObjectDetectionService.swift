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
    // MARK: - Constants
    private enum Constants {
        static let labelBall = "ball"
        static let labelNet = "net"
        static let labelRacquet = "racquet"
        
        static let minBallSizeRatio: CGFloat = 0.5
        static let maxBallSizeRatio: CGFloat = 2.0
        
        static let ballConfidenceThreshold: Float = 0.5
        static let netConfidenceThreshold: Float = 0.5
        static let racquetConfidenceThreshold: Float = 0.5
        
        static let movingAverageWeight: CGFloat = 0.1
    }
    
    // MARK: - Properties
    private var racquetBallNetDetectionModel: VNCoreMLModel?
    private var racquetBallNetDetectionRequest: VNCoreMLRequest?
    
    private var currentPixelBuffer: CVPixelBuffer?
    private var detectionCompletionHandler: ((RacquetBallNetDetectionResults) -> Void)?
    
    private var averageBallSize: CGFloat = 0.0
    
    // MARK: - Initialization
    init() {
        setupRacquetBallNetDetection()
    }
    
    // MARK: - Private Methods
    private func setupRacquetBallNetDetection() {
        do {
            let config = MLModelConfiguration()
            let model = try RacquetBallNetDetect(configuration: config).model
            let vnModel = try VNCoreMLModel(for: model)
            self.racquetBallNetDetectionModel = vnModel
            
            self.racquetBallNetDetectionRequest = VNCoreMLRequest(model: vnModel) { [weak self] (request, error) in
                self?.handleObjectDetectionCompleted(for: request, error: error)
            }
            self.racquetBallNetDetectionRequest?.imageCropAndScaleOption = .scaleFill
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
            
            if confidence > Constants.ballConfidenceThreshold && label == Constants.labelBall {
                // Validate ball size if we have an average
                let ballArea = boundingBox.width * boundingBox.height
                let isValidSize = averageBallSize == 0.0 ||
                    (ballArea >= averageBallSize * Constants.minBallSizeRatio &&
                     ballArea <= averageBallSize * Constants.maxBallSizeRatio)
                
                if isValidSize {
                    currentBallPosition = boundingBox
                    updateAverageBallSize(ballArea)
                }
            } else if confidence > Constants.netConfidenceThreshold && label == Constants.labelNet {
                currentNetPosition = boundingBox
            } else if confidence > Constants.racquetConfidenceThreshold && label == Constants.labelRacquet {
                currentRacquetPosition = boundingBox
            }
            
            // Only add high-confidence detections to UI
            if (label == Constants.labelBall && confidence > Constants.ballConfidenceThreshold) ||
               (label == Constants.labelNet && confidence > Constants.netConfidenceThreshold) ||
               (label == Constants.labelRacquet && confidence > Constants.racquetConfidenceThreshold) {
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
            averageBallSize = averageBallSize * (1.0 - Constants.movingAverageWeight) + ballArea * Constants.movingAverageWeight
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
