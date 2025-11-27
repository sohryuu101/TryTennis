import Foundation
import CoreML
import Vision
import UIKit

/// Service for classifying tennis grip using ML
class GripClassificationService {
    // MARK: - Types
    enum GripConfidenceLevel {
        case perfect    // 85-100%
        case great      // 60-84%
        case keepGoing  // 0-59%
        
        var messages: [String] {
            switch self {
            case .perfect:
                return ["Perfect Grip!", "Maintain your grip like this"]
            case .great:
                return ["Great Grip!", "Your grip is great enough to play"]
            case .keepGoing:
                return ["Keep Going!", "Try to adjust your grip and photo angle"]
            }
        }
    }
    
    // MARK: - Public Methods
    /// Classify the grip from an image
    public func classifyGrip(from image: UIImage, completion: @escaping (Result<(confidence: Int, level: GripConfidenceLevel), Error>) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(.failure(NSError(domain: "GripClassificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CIImage"])))
            return
        }
        
        do {
            let config = MLModelConfiguration()
            let coreMLModel = try GripClassifier(configuration: config).model
            let vnModel = try VNCoreMLModel(for: coreMLModel)
            
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let results = request.results as? [VNClassificationObservation] {
                    // Find the top classification that contains "Eastern"
                    if let easternResult = results.first(where: { $0.identifier.localizedCaseInsensitiveContains("Eastern") }) {
                        let confidence = Int(easternResult.confidence * 100)
                        let level = self.getConfidenceLevel(for: confidence)
                        completion(.success((confidence, level)))
                    } else if let _ = results.first {
                        // Fallback to top result if no Eastern found
                        completion(.success((0, .keepGoing)))
                    } else {
                        completion(.failure(NSError(domain: "GripClassificationService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No results found"])))
                    }
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Private Methods
    private func getConfidenceLevel(for confidence: Int) -> GripConfidenceLevel {
        switch confidence {
        case 85...100:
            return .perfect
        case 60...84:
            return .great
        default:
            return .keepGoing
        }
    }
}
