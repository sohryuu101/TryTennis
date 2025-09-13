import Foundation
import Vision
import AVFoundation

struct AngleClassifierResult {
    let angleResult: String
    let confidence: Float
}

class AngleClassifier {
    // --- Properties for the ML Model ---
    private var headAngleRequest: VNCoreMLRequest?
    
    // --- Internal properties for a single detection pass ---
    private var classificationCompletionHandler: ((AngleClassifierResult) -> Void)?
    
    init() {
        setupHeadAngleRequest()
    }
    
    private func setupHeadAngleRequest() {
        do {
            let model = try HeadAngle(configuration: MLModelConfiguration()).model
            let visionModel = try VNCoreMLModel(for: model)
            headAngleRequest = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                self?.handleAngleClassificationCompleted(for: request, error: error)
            }
            headAngleRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load HeadAngle ML model: \(error)")
        }
    }
    
    public func classify(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (AngleClassifierResult) -> Void) {
        self.classificationCompletionHandler = completionHandler
        
        guard let request = self.headAngleRequest else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform head angle classification request: \(error.localizedDescription)")
        }
    }
    
    private func handleAngleClassificationCompleted(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation],
              let topResult = results.first else {
            return
        }
        
        // Immediately update the angle classification without delay
        let angleClassification = topResult.identifier
        
        let classificationResult = AngleClassifierResult(
            angleResult: angleClassification,
            confidence: topResult.confidence
        )
        
        classificationCompletionHandler?(classificationResult)

    }
}
