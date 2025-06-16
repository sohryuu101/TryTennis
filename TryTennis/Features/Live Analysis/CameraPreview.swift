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
        
        view.layer.addSublayer(previewLayer) // Add previewLayer first
        context.coordinator.previewLayer = previewLayer

        // Add overlay view for drawing bounding boxes on top of the previewLayer
        let overlayView = UIView()
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
        context.coordinator.overlayView = overlayView
        
        // Remove statistics view and labels as they are handled in SwiftUI in LiveAnalysisView
        // Add statistics view
        // let statsView = UIView()
        // statsView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        // statsView.layer.cornerRadius = 10
        // view.addSubview(statsView)
        // context.coordinator.statsView = statsView
        
        // Add statistics labels
        // let successfulLabel = UILabel()
        // successfulLabel.textColor = .white
        // successfulLabel.font = .systemFont(ofSize: 14, weight: .medium)
        // statsView.addSubview(successfulLabel)
        // context.coordinator.successfulLabel = successfulLabel
        
        // let failedLabel = UILabel()
        // failedLabel.textColor = .white
        // failedLabel.font = .systemFont(ofSize: 14, weight: .medium)
        // statsView.addSubview(failedLabel)
        // context.coordinator.failedLabel = failedLabel
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the frame to match the view's bounds
        context.coordinator.previewLayer?.frame = uiView.bounds
        context.coordinator.overlayView?.frame = uiView.bounds
        // context.coordinator.statsView?.frame = CGRect(x: 16, y: 16, width: 200, height: 80)
        
        // Update statistics labels (commented out as handled by SwiftUI)
        // context.coordinator.successfulLabel?.text = "Successful: \(cameraService.successfulShots)"
        // context.coordinator.failedLabel?.text = "Failed: \(cameraService.failedShots)"
        // context.coordinator.successfulLabel?.frame = CGRect(x: 16, y: 16, width: 168, height: 20)
        // context.coordinator.failedLabel?.frame = CGRect(x: 16, y: 44, width: 168, height: 20)
        
        // Update bounding boxes
        context.coordinator.updateBoundingBoxes(cameraService.detectedObjects)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?
        var overlayView: UIView?
        // Removed statsView, successfulLabel, failedLabel
        var boundingBoxLayers: [CALayer] = []
        
        init(_ parent: CameraPreview) { 
            self.parent = parent 
        }
        
        func updateBoundingBoxes(_ objects: [DetectedObject]) {
            // Remove old bounding boxes
            boundingBoxLayers.forEach { $0.removeFromSuperlayer() }
            boundingBoxLayers.removeAll()
            
            guard let overlayView = overlayView else { return }
            
            // Add new bounding boxes
            for object in objects {
                let boundingBox = object.boundingBox
                let layer = CAShapeLayer()
                layer.frame = CGRect(
                    x: boundingBox.minX * overlayView.bounds.width,
                    y: (1 - boundingBox.maxY) * overlayView.bounds.height, // Adjust Y for UIKit coordinates
                    width: boundingBox.width * overlayView.bounds.width,
                    height: boundingBox.height * overlayView.bounds.height
                )
                
                layer.strokeColor = object.label == "ball" ? UIColor.green.cgColor : UIColor.red.cgColor
                layer.fillColor = UIColor.clear.cgColor
                layer.lineWidth = 2
                
                let path = UIBezierPath(rect: layer.bounds)
                layer.path = path.cgPath
                
                overlayView.layer.addSublayer(layer)
                boundingBoxLayers.append(layer)
                
                // Add label
                let labelLayer = CATextLayer()
                labelLayer.string = "\(object.label) (\(Int(object.confidence * 100))%)"
                labelLayer.fontSize = 12
                labelLayer.foregroundColor = UIColor.white.cgColor
                labelLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                labelLayer.cornerRadius = 4
                labelLayer.frame = CGRect(
                    x: layer.frame.minX,
                    y: layer.frame.minY - 20, // Position above the bounding box
                    width: 100,
                    height: 20
                )
                overlayView.layer.addSublayer(labelLayer)
                boundingBoxLayers.append(labelLayer)
            }
        }
    }
}
