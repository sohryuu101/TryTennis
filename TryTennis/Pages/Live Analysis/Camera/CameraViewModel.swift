import Foundation
import AVFoundation
import CoreML
import Photos
import PhotosUI
import SwiftData
import Vision
import WatchConnectivity

/// Refactored ViewModel for Camera and Live Analysis
/// Reduced from 354 lines to ~180 lines by extracting coordinators
/// Now acts as a facade that delegates to specialized components
class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published UI State

    @Published var strokeClassification: String = "Ready"
    @Published var isProcessing = false
    @Published var player: AVPlayer?
    @Published var isVideoReady = false
    @Published var totalAttempts: Int = 0
    @Published var successfulShots: Int = 0
    @Published var failedShots: Int = 0
    @Published var currentStatus: String = "Ready to start"
    @Published var angleClassification: String = ""
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isBodyPoseDetected: Bool = true

    // MARK: - Coordinators

    private let cameraManager: CameraManager
    private let mlOrchestrator: MLAnalysisOrchestrator
    private let sessionRecorder: SessionRecorder

    // MARK: - Properties

    var modelContext: ModelContext? = nil
    var frameSkip = 1

    // Expose session for View consumption
    var captureSession: AVCaptureSession {
        return cameraManager.captureSession
    }

    // MARK: - Initialization

    override init() {
        // Initialize coordinators
        self.cameraManager = CameraManager()
        self.mlOrchestrator = MLAnalysisOrchestrator()
        self.sessionRecorder = SessionRecorder()

        super.init()

        // Setup delegates
        setupCoordinators()
        setupCamera()
    }

    // MARK: - Setup

    private func setupCoordinators() {
        cameraManager.delegate = self
        mlOrchestrator.delegate = self
        sessionRecorder.delegate = self
    }

    private func setupCamera() {
        Task {
            do {
                try await cameraManager.setupCamera()
                await cameraManager.startSession()

                await MainActor.run {
                    self.isVideoReady = true
                    self.strokeClassification = "Camera ready - Tap to start racquet analysis"
                }
            } catch {
                await MainActor.run {
                    self.strokeClassification = "Camera setup failed: \(error.localizedDescription)"
                    self.isVideoReady = false
                }
            }
        }
    }

    // MARK: - Session Management

    func restartCamera() {
        cameraManager.restartSession()
    }

    func setContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        sessionRecorder.setModelContext(modelContext)
    }

    // MARK: - Processing Control

    func toggleProcessing() {
        isProcessing.toggle()
        if isProcessing {
            startProcessing()
        } else {
            stopProcessing()
        }
    }

    private func startProcessing() {
        strokeClassification = "🎾 Detecting racquet and ball proximity..."
        resetProcessingState()

        Task {
            do {
                let outputURL = try await sessionRecorder.startRecording()
                cameraManager.startRecording(to: outputURL)
            } catch {
                await MainActor.run {
                    self.strokeClassification = "Failed to start recording: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    private func stopProcessing() {
        strokeClassification = "Paused"
        cameraManager.stopRecording()
        WatchConnectivityManager.shared.sendSessionEndedFeedback()
    }

    private func resetProcessingState() {
        mlOrchestrator.resetPoseSequence()
        mlOrchestrator.resetStatistics()

        DispatchQueue.main.async {
            self.totalAttempts = 0
            self.successfulShots = 0
            self.failedShots = 0
            self.currentStatus = "Ready"
        }
    }

    // MARK: - Public API for View

    func resetStatistics() {
        resetProcessingState()
    }
}

// MARK: - CameraManagerDelegate

extension CameraViewModel: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        guard isProcessing else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Process frame through ML pipeline
        mlOrchestrator.processFrame(pixelBuffer)
    }

    func cameraManager(_ manager: CameraManager, didFinishRecordingTo outputFileURL: URL, error: Error?) {
        // Get current statistics
        let stats = mlOrchestrator.getStatistics()
        let state = SessionRecorder.RecordingState(
            totalAttempts: stats.total,
            successfulShots: stats.successful,
            failedShots: stats.failed
        )

        // Finish recording (save to Photos + SwiftData)
        sessionRecorder.finishRecording(videoURL: outputFileURL, statistics: state)
    }

    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        Task { @MainActor in
            self.currentStatus = "Camera Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - MLAnalysisOrchestratorDelegate

extension CameraViewModel: MLAnalysisOrchestratorDelegate {
    func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didUpdateResult result: MLAnalysisOrchestrator.AnalysisResult) {
        DispatchQueue.main.async {
            self.isBodyPoseDetected = result.isBodyPoseDetected
            self.detectedObjects = result.detectedObjects
            self.angleClassification = result.angleClassification
        }
    }

    func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didDetectSwing swingDetected: Bool) {
        // Swing detected - you can update UI here if needed
    }

    func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didCrossNet result: NetCrossingResult) {
        DispatchQueue.main.async {
            switch result {
            case .success_over_net:
                let stats = self.mlOrchestrator.getStatistics()
                self.successfulShots = stats.successful
                self.totalAttempts = stats.total

                WatchConnectivityManager.shared.sendImmediateShotFeedback(
                    angle: "Success",
                    isSuccessful: true
                )

            case .failed_hit_net, .failed_under_net:
                let stats = self.mlOrchestrator.getStatistics()
                self.failedShots = stats.failed
                self.totalAttempts = stats.total

            case .uncertain:
                break
            }
        }
    }
}

// MARK: - SessionRecorderDelegate

extension CameraViewModel: SessionRecorderDelegate {
    func sessionRecorder(_ recorder: SessionRecorder, didUpdateState state: SessionRecorder.RecordingState) {
        DispatchQueue.main.async {
            self.totalAttempts = state.totalAttempts
            self.successfulShots = state.successfulShots
            self.failedShots = state.failedShots
        }
    }

    func sessionRecorder(_ recorder: SessionRecorder, didEncounterError error: Error) {
        Task { @MainActor in
            self.currentStatus = "Recording Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sendable

extension CameraViewModel: @unchecked Sendable { }
