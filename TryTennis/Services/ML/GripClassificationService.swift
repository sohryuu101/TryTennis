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
    
    enum ClassificationError: LocalizedError {
        case failedToCreateCIImage
        case noResultsFound
        case modelInitializationFailed
        
        var errorDescription: String? {
            switch self {
            case .failedToCreateCIImage:
                return "Failed to create CIImage from input image."
            case .noResultsFound:
                return "No classification results found."
            case .modelInitializationFailed:
                return "Failed to initialize the ML model."
            }
        }
    }
    
    // MARK: - Properties
    // Cache the model to avoid expensive reloading
    private lazy var vnModel: VNCoreMLModel? = {
        do {
            let config = MLModelConfiguration()
            let coreMLModel = try GripClassifier(configuration: config).model
            return try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("Failed to load GripClassifier: \(error)")
            return nil
        }
    }()
    
    // MARK: - Public Methods
    /// Classify the grip from an image
    /// - Parameter image: The image to classify
    /// - Returns: A tuple containing the confidence score and the grip level
    public func classifyGrip(from image: UIImage) async throws -> (confidence: Int, level: GripConfidenceLevel) {
        guard let ciImage = CIImage(image: image) else {
            throw ClassificationError.failedToCreateCIImage
        }
        
        guard let model = self.vnModel else {
            throw ClassificationError.modelInitializationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let self = self else { return }
                
                if let results = request.results as? [VNClassificationObservation] {
                    // Find the top classification that contains "Eastern"
                    if let easternResult = results.first(where: { $0.identifier.localizedCaseInsensitiveContains("Eastern") }) {
                        let confidence = Int(easternResult.confidence * 100)
                        let level = self.getConfidenceLevel(for: confidence)
                        continuation.resume(returning: (confidence, level))
                    } else if results.first != nil {
                        // Fallback to top result if no Eastern found, but imply low confidence for specific target
                        continuation.resume(returning: (0, .keepGoing))
                    } else {
                        continuation.resume(throwing: ClassificationError.noResultsFound)
                    }
                } else {
                    continuation.resume(throwing: ClassificationError.noResultsFound)
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
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
