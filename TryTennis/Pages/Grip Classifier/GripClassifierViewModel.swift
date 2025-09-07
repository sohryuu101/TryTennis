import CoreML
import SwiftUI
import Vision

class GripClassifierViewModel: ObservableObject {
    @Published var image: UIImage? = nil {
        didSet{
            classifyImage()
        }
    }
    @Published var classificationResult: [String] = []
    @Published var descriptionResult: String = ""
    
    @Published var showCamera = false
    @Published var showPhotoResult = false
    var result: Int = 0
    
    let gripGuide: [Guide] = [
        Guide(image: "grip_guide_1", title: "Index knuckle on bevel 3"),
        Guide(image: "grip_guide_2", title: "Grip handle like a handshake"),
        Guide(image: "grip_guide_3", title: "Ensure the photo brightness")
    ]

    func classifyImage() {
        guard let imageToClassify = self.image else {
            classificationResult = []
            return
        }

        guard let ciImage = CIImage(image: imageToClassify) else {
            classificationResult = []
            return
        }

        do {
            let config = MLModelConfiguration()
            let coreMLModel = try GripClassifier(configuration: config).model
            let vnModel = try VNCoreMLModel(for: coreMLModel)
            
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let results = request.results as? [VNClassificationObservation] {
                    // Find the top classification that contains "Eastern"
                    if let easternResult = results.first(where: { $0.identifier.localizedCaseInsensitiveContains("Eastern") }) {
                        DispatchQueue.main.async {
                            self.classificationResult = self.getConfidenceLabel(for: Int(easternResult.confidence * 100))
                            self.result = Int(easternResult.confidence * 100)
                        }
                    } else if let top = results.first {
                        // fallback to top result if no Eastern found
                        DispatchQueue.main.async {
                            self.classificationResult = self.getConfidenceLabel(for: Int(top.confidence * 100))
                            self.result = 0
                        }
                    }
                } else if let error = error {
                    DispatchQueue.main.async {
                        self.classificationResult = ["Error occurred", "\(error.localizedDescription)"]
                        self.result = 0
                    }
                }
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])

        } catch {
            self.classificationResult = ["Error occurred", "\(error.localizedDescription)"]
        }
    }
    
    func closeResult(){
        self.showPhotoResult = false
        self.image = nil
        self.classificationResult = []
    }
    
    func takePhoto(){
        self.showCamera = true
        self.showPhotoResult = false
        self.classificationResult = []
    }
    
    func getConfidenceLabel(for confidence: Int) -> [String] {
        print("Check")
        switch confidence {
            case 85...100:
                return ["Perfect Grip!", "Maintain your grip like this"]
            case 60...84:
                return ["Great Grip!", "Your grip is great enough to play"]
            default:
                return ["Keep Going!", "Try to adjust your grip and photo angle"]
        }
    }
}
