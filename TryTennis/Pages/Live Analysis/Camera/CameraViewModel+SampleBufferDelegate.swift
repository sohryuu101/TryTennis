import Foundation
import AVFoundation
import Photos

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            // Save session data without video if recording failed
            DispatchQueue.main.async { [weak self] in
                self?.saveSessionData(videoLocalIdentifier: nil)
            }
            try? FileManager.default.removeItem(at: outputFileURL) // Clean up temporary file
            return
        }
        
        // Save the recorded video to Photos library
        var localIdentifier: String? = nil
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            localIdentifier = creationRequest?.placeholderForCreatedAsset?.localIdentifier
        }) { [weak self] saved, error in
            DispatchQueue.main.async {
                if saved {
                    self?.saveSessionData(videoLocalIdentifier: localIdentifier)
                } else {
                    print("Error saving video to Photos library: \(error?.localizedDescription ?? "unknown error")")
                    self?.saveSessionData(videoLocalIdentifier: nil)
                }
                // Delete the temporary video file after it's been handled by Photos
                try? FileManager.default.removeItem(at: outputFileURL)
            }
        }
    }
}
