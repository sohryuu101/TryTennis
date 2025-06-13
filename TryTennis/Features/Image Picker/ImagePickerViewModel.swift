import CoreML
import SwiftUI
import Vision

class ImagePickerViewModel: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var classificationResult: String = ""
    @Published var showCamera = false

    func classifyImage() {
        guard let imageToClassify = self.image else {
            classificationResult = "No image selected"
            return
        }

        guard let ciImage = CIImage(image: imageToClassify) else {
            classificationResult = "Invalid image"
            return
        }

        do {
            let config = MLModelConfiguration()
            let coreMLModel = try GripClassifier(configuration: config).model
            let vnModel = try VNCoreMLModel(for: coreMLModel)
            
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let results = request.results as? [VNClassificationObservation],
                   let top = results.first {
                    DispatchQueue.main.async {
                        self.classificationResult = "\(top.identifier) (\(Int(top.confidence * 100))%)"
                    }
                }
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])

        } catch {
            classificationResult = "Failed to classify image: \(error.localizedDescription)"
        }
    }
    
    func takePhoto(){
        self.showCamera = true
        self.classificationResult = ""
    }
}
