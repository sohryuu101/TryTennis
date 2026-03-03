import Foundation
import AVFoundation

/// Manages camera lifecycle and delegates frame processing
class CameraManager: NSObject {

    // MARK: - Types

    protocol Delegate: AnyObject {
        func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
        func cameraManager(_ manager: CameraManager, didEncounterError error: Error)
        func cameraManager(_ manager: CameraManager, didFinishRecordingTo outputFileURL: URL, error: Error?)
    }

    // MARK: - Properties

    private let cameraService = CameraService()
    weak var delegate: Delegate?

    var captureSession: AVCaptureSession {
        return cameraService.session
    }

    // MARK: - Initialization

    override init() {
        super.init()
        cameraService.delegate = self
    }

    // MARK: - Camera Lifecycle

    func setupCamera() async throws {
        try await cameraService.setupCamera()
    }

    func startSession() async {
        await cameraService.startSession()
    }

    func stopSession() {
        cameraService.stopSession()
    }

    func restartSession() {
        stopSession()
        Task {
            do {
                try await setupCamera()
                await startSession()
            } catch {
                delegate?.cameraManager(self, didEncounterError: error)
            }
        }
    }

    // MARK: - Recording

    func startRecording(to outputURL: URL) {
        cameraService.startRecording(to: outputURL)
    }

    func stopRecording() {
        cameraService.stopRecording()
    }
}

// MARK: - CameraServiceDelegate

extension CameraManager: CameraServiceDelegate {
    func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)
    }

    func cameraService(_ service: CameraService, didEncounterError error: Error) {
        delegate?.cameraManager(self, didEncounterError: error)
    }

    func cameraService(_ service: CameraService, didFinishRecordingTo outputFileURL: URL, error: Error?) {
        delegate?.cameraManager(self, didFinishRecordingTo: outputFileURL, error: error)
    }
}

// MARK: - Type Alias for CameraManagerDelegate

typealias CameraManagerDelegate = CameraManager.Delegate

