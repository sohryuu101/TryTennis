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
    
    let photoGuideTutorial: [Guide] = [
        Guide(image: "photo_guide_1", title: "Use a tennis racquet", description: "Make sure the racquet is fully visible from handle until head"),
        Guide(image: "photo_guide_2", title: "Use right hand", description: "For better accuracy, please use your right hand to hold the racquet"),
        Guide(image: "photo_guide_3", title: "Make sure the lighting is bright enough", description: "Avoid shadows that cover details."),
        Guide(image: "photo_guide_4", title: "Keep the background clean", description: "Ensure the background is free of distractions")
    ]
    
    let forehandGrip: [Guide] = [
        Guide(image: "forehand_grip_1", title: "Turn the racquet upright", description: "Place your index knuckle on bevel 3"),
        Guide(image: "forehand_grip_2", title: "Grip handle like a handshake", description: "Place each finger beside the others"),
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
            case 90...100:
                return ["Perfect Grip!", "You're nailing it like a pro! Keep holding your racquet just like this"]
            case 70...89:
                return ["Great Grip!", "Almost perfect! Just a tiny tweak and you’re there"]
            case 50...69:
                return ["Good Grip!", "Just a few adjustments will make your grip even better!"]
            default:
                return ["Keep Going!", "Let’s try again. Try adjusting your fingers and racquet angle"]
        }
    }
}
