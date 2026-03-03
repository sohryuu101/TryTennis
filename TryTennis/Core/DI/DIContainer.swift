import Foundation

/// Dependency Injection Container for managing service lifecycle
/// Supports singleton and transient registrations
class DIContainer {

    // MARK: - Singleton

    static let shared = DIContainer()

    // MARK: - Properties

    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        registerDefaults()
    }

    // MARK: - Registration

    /// Register a singleton instance
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        services[key] = instance
    }

    /// Register a factory for transient instances
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
    }

    /// Register a singleton with a factory that creates it once
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        // Create instance immediately
        services[key] = factory()
    }

    // MARK: - Resolution

    /// Resolve a dependency by type
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        lock.lock()
        defer { lock.unlock() }

        // Check for singleton
        if let service = services[key] as? T {
            return service
        }

        // Check for factory
        if let factory = factories[key] as? () -> T {
            return factory()
        }

        return nil
    }

    /// Force unwrap version for when you know the dependency exists
    func forceResolve<T>(_ type: T.Type) -> T {
        guard let service: T = resolve(type) else {
            fatalError("Dependency \(type) not registered in DIContainer")
        }
        return service
    }

    // MARK: - Default Registrations

    private func registerDefaults() {
        // Register singletons
        registerSingleton(WatchConnectivityManager.self) {
            WatchConnectivityManager.shared
        }

        registerSingleton(PerformanceMonitor.self) {
            PerformanceMonitor.shared
        }

        registerSingleton(MLPerformanceOrchestrator.self) {
            MLPerformanceOrchestrator.shared
        }

        // Register factories for other services
        register(CameraService.self) {
            CameraService()
        }

        register(SwingPoseDetectionService.self) {
            SwingPoseDetectionService()
        }

        register(ObjectDetectionService.self) {
            ObjectDetectionService()
        }

        register(AngleClassificationService.self) {
            AngleClassificationService()
        }

        register(BallTrackingService.self) {
            BallTrackingService()
        }

        register(ScoringService.self) {
            [weak self] in
            guard let self = self,
                  let ballTracker: BallTrackingService = self.resolve(BallTrackingService.self) else {
                fatalError("BallTrackingService must be registered before ScoringService")
            }
            return ScoringService(ballTrackingService: ballTracker)
        }
    }

    // MARK: - Reset (for testing)

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
        factories.removeAll()
        registerDefaults()
    }
}

// MARK: - Property Wrapper for Easy Injection

@propertyWrapper
struct Injected<T> {
    private let type: T.Type

    var wrappedValue: T {
        guard let service: T = DIContainer.shared.resolve(type) else {
            fatalError("Dependency \(type) not registered in DIContainer")
        }
        return service
    }

    init(_ type: T.Type) {
        self.type = type
    }
}
