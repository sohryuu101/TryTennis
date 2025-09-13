import Foundation
import CoreML
import Vision

struct RacquetBallNetDetectionResults {
    let pixelBuffer: CVPixelBuffer
    let detectedObjects: [DetectedObject]
    let racquetPosition: CGRect?
    let ballPosition: CGRect?
    let netPosition: CGRect?
}


class RacquetBallNetDetection {
    // --- Properties for the ML Model ---
    private var racquetBallNetDetectionModel: VNCoreMLModel?
    private var racquetBallNetDetectionRequest: VNCoreMLRequest?
    
    // --- Internal properties for a single detection pass ---
    private var currentPixelBuffer: CVPixelBuffer?
    private var detectionCompletionHandler: ((RacquetBallNetDetectionResults) -> Void)?
    
    // --- Internal properties for detection logic ---
    private var averageBallSize: CGFloat = 0.0
    private let minBallSizeRatio: CGFloat = 0.5
    private let maxBallSizeRatio: CGFloat = 2.0
    private let ballConfidenceThreshold: Float = 0.5
    private let netConfidenceThreshold: Float = 0.5
    private let racquetConfidenceThreshold: Float = 0.5
    
    init() {
        setupRacquetBallNetDetection()
    }
    
    private func setupRacquetBallNetDetection() {
        do {
            let model = try RacquetBallNetDetect(configuration: MLModelConfiguration()).model
            racquetBallNetDetectionModel = try VNCoreMLModel(for: model)
            racquetBallNetDetectionRequest = VNCoreMLRequest(model: racquetBallNetDetectionModel!) { [weak self] (request, error) in
                self?.handleObjectDetectionCompleted(for: request, error: error)
            }
            racquetBallNetDetectionRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load AnotherRacquetDetect ML model: \(error)")
        }
    }
    
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
    
    // Helper method to update average ball size for filtering
    private func updateAverageBallSize(_ ballArea: CGFloat) {
        if averageBallSize == 0.0 {
            averageBallSize = ballArea
        } else {
            // Exponential moving average
            averageBallSize = averageBallSize * 0.9 + ballArea * 0.1
        }
    }
    
}
