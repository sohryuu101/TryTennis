import Foundation
import AVFoundation

// MARK: - Camera Service Protocol

protocol CameraServiceProtocol {
    var session: AVCaptureSession { get }
    func setupCamera() async throws
    func startSession() async
    func stopSession()
    func startRecording(to url: URL)
    func stopRecording()
}

// Make CameraService conform to protocol
extension CameraService: CameraServiceProtocol {}

// MARK: - ML Service Protocols

protocol SwingPoseDetectionServiceProtocol {
    func processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer)
    func resetPoseSequence()
}

extension SwingPoseDetectionService: SwingPoseDetectionServiceProtocol {}

protocol ObjectDetectionServiceProtocol {
    func detectRacquetBallNet(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (RacquetBallNetDetectionResults) -> Void)
}

extension ObjectDetectionService: ObjectDetectionServiceProtocol {}

protocol AngleClassificationServiceProtocol {
    func classify(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (AngleClassifierResult) -> Void)
}

extension AngleClassificationService: AngleClassificationServiceProtocol {}

// MARK: - Tracking & Scoring Protocols

protocol BallTrackingServiceProtocol {
    var ballTrajectory: [BallPosition] { get }
    func updateBallTrajectory(ballPosition: CGRect, frameCount: Int)
    func updateNetPosition(_ netRect: CGRect)
    func resetAllTracking()
}

extension BallTrackingService: BallTrackingServiceProtocol {}

protocol ScoringServiceProtocol {
    func setFrameCount(_ count: Int)
    func incrementSuccessful()
    func incrementFailed()
    func resetStatistics()
    func getStatistics() -> (total: Int, successful: Int, failed: Int)
}

extension ScoringService: ScoringServiceProtocol {}

// MARK: - Watch Connectivity Protocol

protocol WatchConnectivityProtocol {
    func sendShotFeedback(angle: String, isSuccessful: Bool)
    func sendImmediateShotFeedback(angle: String, isSuccessful: Bool)
    func sendSessionEndedFeedback()
    func sendNotInFrameFeedback()
    func sendBackInFrameFeedback()
    func sendLiveAnalysisStartedNotification()
    func clearMessageQueue()
    func forceReconnect()
}

extension WatchConnectivityManager: WatchConnectivityProtocol {}

// MARK: - Mock Implementations for Testing

#if DEBUG

class MockCameraService: CameraServiceProtocol {
    var session: AVCaptureSession = AVCaptureSession()

    func setupCamera() async throws {}
    func startSession() async {}
    func stopSession() {}
    func startRecording(to url: URL) {}
    func stopRecording() {}
}

class MockSwingPoseDetectionService: SwingPoseDetectionServiceProtocol {
    var detectCalled = false
    func processFrameForPoseDetection(_ pixelBuffer: CVPixelBuffer) {
        detectCalled = true
    }
    func resetPoseSequence() {}
}

class MockObjectDetectionService: ObjectDetectionServiceProtocol {
    func detectRacquetBallNet(on pixelBuffer: CVPixelBuffer, completionHandler: @escaping (RacquetBallNetDetectionResults) -> Void) {
        // Mock empty results
        let results = RacquetBallNetDetectionResults(
            pixelBuffer: pixelBuffer,
            detectedObjects: [],
            racquetPosition: nil,
            ballPosition: nil,
            netPosition: nil
        )
        completionHandler(results)
    }
}

class MockWatchConnectivityManager: WatchConnectivityProtocol {
    var shotFeedbackCount = 0
    var sessionEndedCount = 0
    var notInFrameCount = 0
    var backInFrameCount = 0

    func sendShotFeedback(angle: String, isSuccessful: Bool) {
        shotFeedbackCount += 1
    }

    func sendImmediateShotFeedback(angle: String, isSuccessful: Bool) {
        shotFeedbackCount += 1
    }

    func sendSessionEndedFeedback() {
        sessionEndedCount += 1
    }

    func sendNotInFrameFeedback() {
        notInFrameCount += 1
    }

    func sendBackInFrameFeedback() {
        backInFrameCount += 1
    }

    func sendLiveAnalysisStartedNotification() {}
    func clearMessageQueue() {}
    func forceReconnect() {}
}

#endif
