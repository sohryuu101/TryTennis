import AVFoundation
import SwiftUI

struct CameraView: UIViewRepresentable {
    @ObservedObject var cameraService: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoRotationAngle = 0
        
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        let overlayView = UIView()
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
        context.coordinator.overlayView = overlayView
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the frame to match the view's bounds
        context.coordinator.previewLayer?.frame = uiView.bounds
        context.coordinator.overlayView?.frame = uiView.bounds
        
        // Update bounding boxes
        context.coordinator.updateBoundingBoxes(cameraService.detectedObjects)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
}
