import Foundation
import CoreML
import Vision

/// Orchestrates ML performance optimizations: throttling, background queue, memory management
class MLPerformanceOrchestrator {

    // MARK: - Types

    enum Priority {
        case high    // Real-time processing (swing detection)
        case medium  // Object detection
        case low     // Angle classification
    }

    struct MLRequest<T> {
        let priority: Priority
        let operation: () -> T
        let completion: (T) -> Void
        let timestamp: Date
    }

    // MARK: - Properties

    static let shared = MLPerformanceOrchestrator()

    // Background queue for ML processing
    private let mlQueue: DispatchQueue = {
        let queue = DispatchQueue(
            label: "com.trytennis.mlProcessing",
            qos: .userInitiated,
            attributes: .concurrent
        )
        return queue
    }()

    // Serial queue for managing throttling state
    private let throttlingQueue = DispatchQueue(label: "com.trytennis.mlThrottling")

    // Throttling configuration
    private var lastExecutionTime: [String: Date] = [:]
    private var minimumInterval: [Priority: TimeInterval] = [
        .high: 0,        // No throttling for high priority
        .medium: 0.033,  // ~30fps for medium
        .low: 0.100      // ~10fps for low priority
    ]

    // Memory management
    private let memoryThresholdMB: Double = 500.0  // 500MB threshold
    private var isMemoryPressureDetected = false

    // Request queue for pending operations
    private var requestQueue: [String: [any Any]] = [:]

    // MARK: - Initialization

    private init() {
        setupMemoryMonitoring()
    }

    // MARK: - Public API

    /// Execute ML operation with throttling and performance tracking
    func execute<T>(
        priority: Priority,
        category: String,
        operation: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        throttlingQueue.async { [weak self] in
            guard let self = self else { return }

            // Check throttling
            if self.shouldThrottle(priority: priority, category: category) {
                // Skip this request
                return
            }

            // Update last execution time
            self.lastExecutionTime[category] = Date()

            // Execute on background ML queue
            self.mlQueue.async { [weak self] in
                guard let self = self else { return }

                // Track performance
                let tracker = PerformanceTracker(label: category, logThreshold: 0.100)

                // Execute operation
                let result = operation()

                // Stop tracking
                let duration = tracker.stop()

                // Update metrics
                if priority == .high {
                    PerformanceMonitor.shared.trackSwingPoseDetection(duration: duration)
                } else if priority == .medium {
                    PerformanceMonitor.shared.trackObjectDetection(duration: duration)
                } else if priority == .low {
                    PerformanceMonitor.shared.trackAngleClassification(duration: duration)
                }

                // Complete on main thread
                DispatchQueue.main.async {
                    completion(result)
                }

                // Memory check after processing
                self.checkMemoryPressure()
            }
        }
    }

    /// Execute async ML operation (for Vision/CoreML async APIs)
    func executeAsync<T>(
        priority: Priority,
        category: String,
        operation: @escaping (@escaping (T) -> Void) -> Void,
        completion: @escaping (T) -> Void
    ) {
        throttlingQueue.async { [weak self] in
            guard let self = self else { return }

            // Check throttling
            if self.shouldThrottle(priority: priority, category: category) {
                return
            }

            // Update last execution time
            self.lastExecutionTime[category] = Date()

            // Execute on background ML queue
            self.mlQueue.async { [weak self] in
                guard let self = self else { return }

                let tracker = PerformanceTracker(label: category)

                // Execute async operation
                operation { result in
                    let duration = tracker.stop()

                    // Update metrics
                    if priority == .high {
                        PerformanceMonitor.shared.trackSwingPoseDetection(duration: duration)
                    } else if priority == .medium {
                        PerformanceMonitor.shared.trackObjectDetection(duration: duration)
                    } else if priority == .low {
                        PerformanceMonitor.shared.trackAngleClassification(duration: duration)
                    }

                    // Complete on main thread
                    DispatchQueue.main.async {
                        completion(result)
                    }

                    self.checkMemoryPressure()
                }
            }
        }
    }

    // MARK: - Throttling Logic

    private func shouldThrottle(priority: Priority, category: String) -> Bool {
        // No throttling for high priority
        guard priority != .high,
              let interval = minimumInterval[priority],
              let lastTime = lastExecutionTime[category] else {
            return false
        }

        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed < interval
    }

    /// Configure throttling interval for a priority level
    func setThrottlingInterval(priority: Priority, interval: TimeInterval) {
        throttlingQueue.async { [weak self] in
            self?.minimumInterval[priority] = interval
        }
    }

    /// Reset throttling state (e.g., when starting new session)
    func resetThrottling() {
        throttlingQueue.async { [weak self] in
            self?.lastExecutionTime.removeAll()
        }
    }

    // MARK: - Memory Management

    private func setupMemoryMonitoring() {
        // Check memory every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
    }

    private func checkMemoryPressure() {
        PerformanceMonitor.shared.updateMemoryUsage()
        let memoryMB = PerformanceMonitor.shared.getMemoryUsageMB()

        if memoryMB > memoryThresholdMB {
            if !isMemoryPressureDetected {
                isMemoryPressureDetected = true
                print("⚠️ Memory pressure detected: \(String(format: "%.1f", memoryMB))MB")

                // Could trigger cleanup here
                cleanupResources()
            }
        } else {
            isMemoryPressureDetected = false
        }
    }

    private func cleanupResources() {
        // Force memory cleanup
        autoreleasepool {
            // Clear any caches if needed
            // This is a placeholder for future optimizations
        }
    }

    // MARK: - Batch Processing

    /// Process multiple requests efficiently (future optimization)
    func batchProcess<T, R>(
        items: [T],
        priority: Priority,
        category: String,
        operation: @escaping (T, @escaping (R) -> Void) -> Void,
        completion: @escaping ([R]) -> Void
    ) {
        let group = DispatchGroup()

        var results: [R?] = Array(repeating: nil, count: items.count)

        for (index, item) in items.enumerated() {
            group.enter()
            executeAsync(priority: priority, category: "\(category)_\(index)") { innerCompletion in
                operation(item) { result in
                    results[index] = result
                    innerCompletion(result)
                    group.leave()
                }
            } completion: { _ in
                // Batch completion handled by notify
            }
        }

        group.notify(queue: .main) {
            completion(results.compactMap { $0 })
        }
    }
}

// MARK: - Convenience Extensions

extension MLPerformanceOrchestrator {
    /// Quick execution for swing pose detection (high priority, no throttling)
    func executeSwingDetection(
        pixelBuffer: CVPixelBuffer,
        detector: SwingPoseDetectionService,
        completion: @escaping () -> Void
    ) {
        execute(priority: .high, category: "swingDetection") {
            detector.processFrameForPoseDetection(pixelBuffer)
            return ()
        } completion: { _ in
            completion()
        }
    }

    /// Quick execution for object detection (medium priority)
    func executeObjectDetection(
        pixelBuffer: CVPixelBuffer,
        service: ObjectDetectionService,
        completion: @escaping (RacquetBallNetDetectionResults) -> Void
    ) {
        executeAsync(priority: .medium, category: "objectDetection") { innerCompletion in
            service.detectRacquetBallNet(on: pixelBuffer, completionHandler: innerCompletion)
        } completion: { result in
            completion(result)
        }
    }

    /// Quick execution for angle classification (low priority)
    func executeAngleClassification(
        pixelBuffer: CVPixelBuffer,
        service: AngleClassificationService,
        completion: @escaping (AngleClassifierResult) -> Void
    ) {
        executeAsync(priority: .low, category: "angleClassification") { innerCompletion in
            service.classify(on: pixelBuffer, completionHandler: innerCompletion)
        } completion: { result in
            completion(result)
        }
    }
}
