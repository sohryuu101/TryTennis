import Foundation
import OSLog

/// Monitors performance metrics for ML pipeline and memory usage
class PerformanceMonitor {

    // MARK: - Types

    struct Metrics {
        var frameProcessingTime: TimeInterval = 0
        var mlInferenceTime: TimeInterval = 0
        var memoryUsage: UInt64 = 0
        var fps: Double = 0
        var droppedFrames: Int = 0
        var totalFrames: Int = 0
    }

    struct MLTimingMetrics {
        var swingPoseDetection: TimeInterval = 0
        var objectDetection: TimeInterval = 0
        var angleClassification: TimeInterval = 0
        var totalMLTime: TimeInterval = 0
    }

    // MARK: - Properties

    static let shared = PerformanceMonitor()

    private var currentMetrics = Metrics()
    private var mlTimingMetrics = MLTimingMetrics()
    private var frameStartTime: Date?
    private var lastFrameTime: Date?
    let logger = Logger(subsystem: "com.TryTennis", category: "Performance")

    private let fpsUpdateInterval: TimeInterval = 1.0
    private var fpsTimer: Timer?

    // MARK: - Computed Properties

    var currentMetricsSnapshot: Metrics {
        return currentMetrics
    }

    var mlTimingSnapshot: MLTimingMetrics {
        return mlTimingMetrics
    }

    // MARK: - Initialization

    private init() {
        startFPSTracking()
    }

    // MARK: - Frame Tracking

    func startFrame() {
        frameStartTime = Date()
        currentMetrics.totalFrames += 1
    }

    func endFrame() {
        guard let start = frameStartTime else { return }
        let processingTime = Date().timeIntervalSince(start)
        currentMetrics.frameProcessingTime = processingTime

        // Check if frame took too long (> 33ms = dropped frame for 30fps)
        if processingTime > 0.033 {
            currentMetrics.droppedFrames += 1
        }
    }

    // MARK: - ML Inference Timing

    func trackSwingPoseDetection(duration: TimeInterval) {
        mlTimingMetrics.swingPoseDetection = duration
        mlTimingMetrics.totalMLTime += duration
    }

    func trackObjectDetection(duration: TimeInterval) {
        mlTimingMetrics.objectDetection = duration
        mlTimingMetrics.totalMLTime += duration
    }

    func trackAngleClassification(duration: TimeInterval) {
        mlTimingMetrics.angleClassification = duration
        mlTimingMetrics.totalMLTime += duration
    }

    // MARK: - Memory Monitoring

    func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            currentMetrics.memoryUsage = info.resident_size
        }
    }

    func getMemoryUsageMB() -> Double {
        return Double(currentMetrics.memoryUsage) / 1024.0 / 1024.0
    }

    // MARK: - FPS Tracking

    private func startFPSTracking() {
        fpsTimer = Timer.scheduledTimer(withTimeInterval: fpsUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateFPS()
        }
    }

    private func updateFPS() {
        guard let lastTime = lastFrameTime else {
            lastFrameTime = Date()
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastTime)
        let frames = self.currentMetrics.totalFrames

        self.currentMetrics.fps = Double(frames) / elapsed

        // Log if FPS is low
        if self.currentMetrics.fps < 20 {
            self.logger.warning("Low FPS detected: \(String(format: "%.1f", self.currentMetrics.fps))")
        }

        // Reset counters
        self.currentMetrics.totalFrames = 0
        self.lastFrameTime = now
    }

    // MARK: - Logging

    func logPerformanceSummary() {
        self.logger.debug("""
        📊 Performance Summary:
        - FPS: \(String(format: "%.1f", self.currentMetrics.fps))
        - Frame Processing: \(String(format: "%.2f", self.currentMetrics.frameProcessingTime * 1000))ms
        - ML Inference: \(String(format: "%.2f", self.mlTimingMetrics.totalMLTime * 1000))ms
        - Memory: \(String(format: "%.1f", self.getMemoryUsageMB()))MB
        - Dropped Frames: \(self.currentMetrics.droppedFrames)
        """)
    }

    // MARK: - Reset

    func reset() {
        currentMetrics = Metrics()
        mlTimingMetrics = MLTimingMetrics()
        frameStartTime = nil
        lastFrameTime = Date()
        logger.debug("Performance metrics reset")
    }
}

// MARK: - Performance Tracking Helper

class PerformanceTracker {
    let startTime: Date
    let label: String
    private let monitor: PerformanceMonitor
    private let logThreshold: TimeInterval

    init(label: String, logThreshold: TimeInterval = 0.050) {
        self.label = label
        self.monitor = .shared
        self.logThreshold = logThreshold
        self.startTime = Date()
    }

    func stop() -> TimeInterval {
        let duration = Date().timeIntervalSince(startTime)

        // Log if operation took longer than threshold
        if duration > self.logThreshold {
            self.monitor.logger.warning("⚠️ \(self.label) took \(String(format: "%.2f", duration * 1000))ms (threshold: \(String(format: "%.2f", self.logThreshold * 1000))ms)")
        }

        return duration
    }

    deinit {
        let duration = Date().timeIntervalSince(startTime)
        // Note: Can't use monitor in deinit
        print("⏱️ \(self.label): \(String(format: "%.2f", duration * 1000))ms")
    }
}
