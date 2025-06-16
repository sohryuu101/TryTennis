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
        previewLayer.connection?.videoRotationAngle = 0
        
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the frame to match the view's bounds
        context.coordinator.previewLayer?.frame = uiView.bounds
        
        // Ensure portrait orientation
        if let connection = context.coordinator.previewLayer?.connection {
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        init(_ parent: CameraPreview) { 
            self.parent = parent 
        }
    }
}
