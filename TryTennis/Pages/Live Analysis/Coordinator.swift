import UIKit
import AVFoundation

class Coordinator: NSObject {
    var parent: CameraView
    var previewLayer: AVCaptureVideoPreviewLayer?
    var overlayView: UIView?
    var boundingBoxLayers: [CALayer] = []
    
    init(_ parent: CameraView) {
        self.parent = parent
    }
    
    func updateBoundingBoxes(_ objects: [DetectedObject]) {
        boundingBoxLayers.forEach { $0.removeFromSuperlayer() }
        boundingBoxLayers.removeAll()
        
        guard let overlayView = overlayView else { return }
        
        // New bounding boxes
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
