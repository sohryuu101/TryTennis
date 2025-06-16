//
//  CameraPreview.swift
//  gatau
//
//  Created by Akbar Febry on 12/06/25.
//
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        
        // Create a layer to draw the bounding box
        let boxLayer = CAShapeLayer()
        boxLayer.strokeColor = UIColor.green.cgColor
        boxLayer.lineWidth = 3.0
        boxLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(boxLayer)
        context.coordinator.boxLayer = boxLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the frame to match the view's bounds
        context.coordinator.previewLayer?.frame = uiView.bounds
        
        // Draw the bounding box if it exists
        if let boundingBox = cameraService.ballBoundingBox {
            // Convert Vision's normalized rect to the preview layer's coordinates
            let convertedRect = context.coordinator.previewLayer?.layerRectConverted(fromMetadataOutputRect: boundingBox) ?? .zero
            
            // Create a path for the rectangle and update the layer
            let path = UIBezierPath(rect: convertedRect)
            context.coordinator.boxLayer?.path = path.cgPath
        } else {
            // If no box, clear the path
            context.coordinator.boxLayer?.path = nil
        }
        
        // The orientation logic remains the same...
        if let connection = context.coordinator.previewLayer?.connection {
             var targetRotationAngle: CGFloat = connection.videoRotationAngle
             switch UIDevice.current.orientation {
             case .landscapeRight: targetRotationAngle = 180
             case .landscapeLeft: targetRotationAngle = 0
             default: break
             }
             if connection.isVideoRotationAngleSupported(targetRotationAngle) {
                 connection.videoRotationAngle = targetRotationAngle
             }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        var boxLayer: CAShapeLayer? // Layer to hold the bounding box
        init(_ parent: CameraPreview) { self.parent = parent }
    }
}
