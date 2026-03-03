import Foundation
import Photos
import SwiftData

/// Manages session recording, saving to Photos, and persisting to SwiftData
class SessionRecorder {

    // MARK: - Types

    struct RecordingState {
        var totalAttempts: Int = 0
        var successfulShots: Int = 0
        var failedShots: Int = 0
        var openRacquetTimestamp: Double? = nil
        var closedRacquetTimestamp: Double? = nil
        var optimalRacquetTimestamp: Double? = nil
    }

    protocol Delegate: AnyObject {
        func sessionRecorder(_ recorder: SessionRecorder, didUpdateState state: RecordingState)
        func sessionRecorder(_ recorder: SessionRecorder, didEncounterError error: Error)
    }

    // MARK: - Properties

    private var modelContext: ModelContext?
    weak var delegate: Delegate?

    private var currentRecordingURL: URL?
    private var state = RecordingState()

    // MARK: - Initialization

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    // MARK: - Model Context

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Recording

    func startRecording() async throws -> URL {
        // Request photo library authorization
        let authorized = await requestPhotoLibraryAuthorization()
        guard authorized else {
            throw RecorderError.photoAccessDenied
        }

        // Create temp file URL
        let outputURL = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).mov")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: outputURL)

        currentRecordingURL = outputURL
        return outputURL
    }

    func finishRecording(videoURL: URL, statistics: RecordingState) {
        self.state = statistics

        // Save to Photos library
        saveToPhotos(videoURL: videoURL)
    }

    private func saveToPhotos(videoURL: URL) {
        var localIdentifier: String? = nil

        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            localIdentifier = creationRequest?.placeholderForCreatedAsset?.localIdentifier
        }) { [weak self] saved, error in
            DispatchQueue.main.async {
                if saved {
                    self?.saveSessionData(videoLocalIdentifier: localIdentifier)
                } else {
                    print("Error saving video to Photos: \(error?.localizedDescription ?? "unknown")")
                    self?.saveSessionData(videoLocalIdentifier: nil)
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: videoURL)
                self?.currentRecordingURL = nil
            }
        }
    }

    private func saveSessionData(videoLocalIdentifier: String?) {
        guard let context = modelContext else { return }

        let newSession = Session(
            timestamp: Date(),
            totalAttempts: state.totalAttempts,
            successfulShots: state.successfulShots,
            failedShots: state.failedShots
        )
        newSession.videoLocalIdentifier = videoLocalIdentifier
        newSession.openRacquetTimestamp = state.openRacquetTimestamp
        newSession.closedRacquetTimestamp = state.closedRacquetTimestamp
        newSession.optimalRacquetTimestamp = state.optimalRacquetTimestamp

        context.insert(newSession)

        delegate?.sessionRecorder(self, didUpdateState: state)
    }

    // MARK: - Helpers

    private func requestPhotoLibraryAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Reset

    func resetState() {
        state = RecordingState()
        delegate?.sessionRecorder(self, didUpdateState: state)
    }
}

// MARK: - Errors

enum RecorderError: LocalizedError {
    case photoAccessDenied

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Photo library access denied"
        }
    }
}

// MARK: - Type Alias

typealias SessionRecorderDelegate = SessionRecorder.Delegate
