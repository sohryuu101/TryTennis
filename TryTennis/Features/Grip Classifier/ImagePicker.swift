import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var showResult: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false

        if let racketImage = UIImage(named: "racket_overlay") {
            let screenBounds = UIScreen.main.bounds
            let screenWidth = screenBounds.width
            let screenHeight = screenBounds.height

            let imageWidth = screenWidth
            let imageHeight = imageWidth * 1.1
            let imageX = (screenWidth - imageWidth) / 2
            let imageY = screenHeight * 0.15

            let imageView = UIImageView(image: racketImage)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
            imageView.isUserInteractionEnabled = false

            overlay.addSubview(imageView)
        }

        picker.cameraOverlayView = overlay
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.showResult = true
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
