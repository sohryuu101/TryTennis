import CoreML
import SwiftUI
import Vision

/// ViewModel for Grip Classifier feature
/// Coordinates UI state and delegates ML processing to GripClassificationService
@MainActor
class GripClassifierViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var image: UIImage? = nil {
        didSet {
            if image != nil {
                classifyImage()
            }
        }
    }
    @Published var classificationResult: [String] = []
    @Published var descriptionResult: String = ""
    @Published var showCamera = false
    @Published var showPhotoResult = false
    @Published var result: Int = 0
    
    // MARK: - Properties
    let gripGuide: [Guide] = [
        Guide(image: "grip_guide_1", title: "Index knuckle on bevel 3"),
        Guide(image: "grip_guide_2", title: "Grip handle like a handshake"),
        Guide(image: "grip_guide_3", title: "Ensure the photo brightness")
    ]
    
    private let gripClassificationService: GripClassificationService
    
    // MARK: - Initialization
    init(gripClassificationService: GripClassificationService = GripClassificationService()) {
        self.gripClassificationService = gripClassificationService
        super.init()
    }
    
    // MARK: - Public Methods
    func classifyImage() {
        guard let imageToClassify = self.image else {
            classificationResult = []
            return
        }
        
        Task {
            do {
                let (confidence, level, label) = try await gripClassificationService.classifyGrip(from: imageToClassify)
                
                // If the detected grip is not Eastern, we might want to inform the user
                // assuming the user is TRYING to do Eastern.
                if !label.localizedCaseInsensitiveContains("Eastern") {
                     self.classificationResult = ["Detected \(label)", "Try adjusting to Eastern Grip"]
                     self.result = confidence // Show the confidence of the detected grip
                } else {
                    self.classificationResult = level.messages
                    self.result = confidence
                }
            } catch {
                self.classificationResult = ["Error occurred", "Please try again"]
                self.result = 0
                print("Classification failed: \(error.localizedDescription)")
            }
        }
    }
    
    func closeResult() {
        self.showPhotoResult = false
        self.image = nil
        self.classificationResult = []
    }
    
    func takePhoto() {
        self.showCamera = true
        self.showPhotoResult = false
        self.classificationResult = []
    }
}
