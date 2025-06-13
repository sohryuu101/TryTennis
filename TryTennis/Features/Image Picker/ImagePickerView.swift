import SwiftUI
import CoreML
import Vision

struct ImagePickerView: View {
    @StateObject var viewModel: ImagePickerViewModel = ImagePickerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }
            
            HStack{
                Button("Take Photo") {
                    viewModel.takePhoto()
                }
                .buttonStyle(.borderedProminent)

                Button("Save") {
                    viewModel.classifyImage()
                }
                .disabled(viewModel.image == nil)
            }

            if viewModel.classificationResult != "" {
                Text("Prediction: \(viewModel.classificationResult)")
                    .padding()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            ImagePicker(image: $viewModel.image)
        }
    }
}

#Preview {
    ImagePickerView()
}
