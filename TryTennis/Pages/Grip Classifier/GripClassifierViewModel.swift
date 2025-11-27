import CoreML
import SwiftUI
import Vision

/// ViewModel for Grip Classifier feature
/// Coordinates UI state and delegates ML processing to GripClassificationService
class GripClassifierViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var image: UIImage? = nil {
        didSet {
            classifyImage()
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
        
        gripClassificationService.classifyGrip(from: imageToClassify) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (confidence, level)):
                    self?.classificationResult = level.messages
                    self?.result = confidence
                case .failure:
                    self?.classificationResult = ["Error occurred", "Please try again"]
                    self?.result = 0
                }
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
