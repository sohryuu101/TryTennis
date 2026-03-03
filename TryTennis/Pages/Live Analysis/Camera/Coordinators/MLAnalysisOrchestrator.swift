import Foundation
import CoreML
import Vision

/// Orchestrates ML analysis pipeline coordinating 4 ML services
/// Pipeline: Swing Pose Detection → Object Detection → Ball Tracking → Angle Classification → Scoring
class MLAnalysisOrchestrator {

    // MARK: - Types

    struct AnalysisResult {
        let isBodyPoseDetected: Bool
        let swingDetected: Bool
        let detectedObjects: [DetectedObject]
        let ballTrajectory: [BallPosition]
        let angleClassification: String
        let crossingResult: NetCrossingResult?
        let gripLabel: String?
    }

    struct ProcessingState {
        var frameCount: Int = 0
        var lastProcessedCrossing: Int = 0
        var isBodyPoseDetected: Bool = true
        var lastRacquetAngleAnalysisTime: Date?
        var racquetAngleAnalysisCooldown: Double = 0.1
    }

    protocol Delegate: AnyObject {
        func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didUpdateResult result: AnalysisResult)
        func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didDetectSwing swingDetected: Bool)
        func mlOrchestrator(_ orchestrator: MLAnalysisOrchestrator, didCrossNet result: NetCrossingResult)
    }

    // MARK: - Type Alias

    var delegate: Delegate?

    // MARK: - Properties

    private let swingPoseDetector: SwingPoseDetectionService
    private let objectDetection: ObjectDetectionService
    private let angleClassifier: AngleClassificationService
    private let ballTracker: BallTrackingService
    private let scoringService: ScoringService

    private var state = ProcessingState()
    private var lastNotInFrameSent: Date? = nil
    private var lastBackInFrameSent: Date? = nil
    private let notInFrameCooldown: Double = 2.0
    private let crossingCooldown = 30

    // MARK: - Computed Properties

    var ballTrajectory: [BallPosition] {
        return ballTracker.ballTrajectory
    }

    // MARK: - Initialization

    init() {
        self.swingPoseDetector = SwingPoseDetectionService()
        self.objectDetection = ObjectDetectionService()
        self.angleClassifier = AngleClassificationService()
        self.ballTracker = BallTrackingService()
        self.scoringService = ScoringService(ballTrackingService: ballTracker)
    }

    // Convenience initializer with DI (for testing)
    init(
        swingPoseDetector: SwingPoseDetectionService,
        objectDetection: ObjectDetectionService,
        angleClassifier: AngleClassificationService,
        ballTracker: BallTrackingService,
        scoringService: ScoringService
    ) {
        self.swingPoseDetector = swingPoseDetector
        self.objectDetection = objectDetection
        self.angleClassifier = angleClassifier
        self.ballTracker = ballTracker
        self.scoringService = scoringService
    }

    // MARK: - Processing

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // Track frame start for performance monitoring
        PerformanceMonitor.shared.startFrame()

        state.frameCount += 1

        // Use MLPerformanceOrchestrator for optimized processing
        MLPerformanceOrchestrator.shared.executeSwingDetection(
            pixelBuffer: pixelBuffer,
            detector: swingPoseDetector
        ) {
            PerformanceMonitor.shared.endFrame()
        }

        // Note: The actual flow is triggered by callbacks from SwingPoseDetectionService
        // When swing is detected, it should call detectObjectsAndTrack()
    }

    /// Called when swing pose detection detects a swing
    func processSwingDetection(detected: Bool, gripLabel: String?) {
        // Notify delegate
        delegate?.mlOrchestrator(self, didDetectSwing: detected)

        // Update body pose detection state
        let previousState = state.isBodyPoseDetected
        state.isBodyPoseDetected = detected

        // Handle not-in-frame feedback
        handleBodyPoseChange(from: previousState, to: detected)
    }

    private func handleBodyPoseChange(from oldValue: Bool, to newValue: Bool) {
        if !newValue && oldValue {
            let now = Date()
            if lastNotInFrameSent == nil || now.timeIntervalSince(lastNotInFrameSent!) > notInFrameCooldown {
                WatchConnectivityManager.shared.sendNotInFrameFeedback()
                lastNotInFrameSent = now
            }
        } else if newValue && !oldValue {
            let now = Date()
            if lastBackInFrameSent == nil || now.timeIntervalSince(lastBackInFrameSent!) > notInFrameCooldown {
                WatchConnectivityManager.shared.sendBackInFrameFeedback()
                lastBackInFrameSent = now
            }
        }
    }

    /// Detect objects (racquet, ball, net) and track ball trajectory
    func detectObjectsAndTrack(from pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        // Use MLPerformanceOrchestrator for optimized object detection
        MLPerformanceOrchestrator.shared.executeObjectDetection(
            pixelBuffer: pixelBuffer,
            service: objectDetection
        ) { [weak self] results in
            guard let self = self else {
                completion([])
                return
            }

            let objects = results.detectedObjects

            // Track ball if detected
            if let ballRect = results.ballPosition {
                self.ballTracker.updateBallTrajectory(ballPosition: ballRect, frameCount: self.state.frameCount)
            }

            // Update net position if detected
            if let netRect = results.netPosition {
                self.ballTracker.updateNetPosition(netRect)
            }

            // Check racquet-ball proximity and analyze angle
            if let racquetRect = results.racquetPosition, let ballRect = results.ballPosition {
                self.checkRacquetBallProximity(
                    racquetPosition: racquetRect,
                    ballPosition: ballRect,
                    pixelBuffer: pixelBuffer
                )
            }

            completion(objects)
        }
    }

    private func checkRacquetBallProximity(racquetPosition: CGRect, ballPosition: CGRect, pixelBuffer: CVPixelBuffer) {
        let racquetCenter = CGPoint(x: racquetPosition.midX, y: racquetPosition.midY)
        let ballCenter = CGPoint(x: ballPosition.midX, y: ballPosition.midY)

        let distance = sqrt(pow(racquetCenter.x - ballCenter.x, 2) + pow(racquetCenter.y - ballCenter.y, 2))
        let proximityThreshold: CGFloat = 0.22

        if distance <= proximityThreshold {
            let currentTime = Date()
            if state.lastRacquetAngleAnalysisTime == nil ||
               currentTime.timeIntervalSince(state.lastRacquetAngleAnalysisTime!) >= state.racquetAngleAnalysisCooldown {

                // Use MLPerformanceOrchestrator for optimized angle classification
                MLPerformanceOrchestrator.shared.executeAngleClassification(
                    pixelBuffer: pixelBuffer,
                    service: angleClassifier
                ) { [weak self] result in
                    guard let self = self else { return }
                    state.lastRacquetAngleAnalysisTime = currentTime

                    // Notify delegate with angle result
                    let analysisResult = AnalysisResult(
                        isBodyPoseDetected: self.state.isBodyPoseDetected,
                        swingDetected: true,
                        detectedObjects: [],
                        ballTrajectory: self.ballTrajectory,
                        angleClassification: result.angleResult,
                        crossingResult: nil,
                        gripLabel: nil
                    )
                    self.delegate?.mlOrchestrator(self, didUpdateResult: analysisResult)
                }
            }
        }
    }

    // MARK: - Net Crossing

    func checkNetCrossing() -> NetCrossingResult? {
        guard state.frameCount - state.lastProcessedCrossing >= crossingCooldown else {
            return nil
        }

        // Check net crossing using scoring service logic
        // TODO: Implement proper net crossing detection based on ball trajectory
        let result: NetCrossingResult = .uncertain

        if case .uncertain = result {
            return nil
        }

        state.lastProcessedCrossing = state.frameCount
        scoringService.setFrameCount(state.frameCount)

        // Update scoring
        switch result {
        case .success_over_net:
            scoringService.incrementSuccessful()
        case .failed_hit_net, .failed_under_net:
            scoringService.incrementFailed()
        case .uncertain:
            break
        }

        // Notify delegate
        delegate?.mlOrchestrator(self, didCrossNet: result)

        // Reset tracking after crossing
        ballTracker.resetAllTracking()

        return result
    }

    // MARK: - Statistics

    func getStatistics() -> (total: Int, successful: Int, failed: Int) {
        let stats = scoringService.getStatistics()
        return (stats.total, stats.successful, stats.failed)
    }

    func resetStatistics() {
        scoringService.resetStatistics()
        ballTracker.resetAllTracking()
        state.frameCount = 0
        state.lastProcessedCrossing = 0
    }

    func resetPoseSequence() {
        swingPoseDetector.resetPoseSequence()
    }

    // MARK: - Timestamp Tracking

    func updateOpenRacquetTimestamp(_ timestamp: Double?) {
        // This will be stored by SessionRecorder
    }

    func updateClosedRacquetTimestamp(_ timestamp: Double?) {
        // This will be stored by SessionRecorder
    }

    func updateOptimalRacquetTimestamp(_ timestamp: Double?) {
        // This will be stored by SessionRecorder
    }
}

// MARK: - Type Alias

typealias MLAnalysisOrchestratorDelegate = MLAnalysisOrchestrator.Delegate
