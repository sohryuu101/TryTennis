import Foundation

/// Base protocol for all services in the app
/// Services encapsulate business logic and are injected into ViewModels
protocol ServiceProtocol {
    /// Initialize the service with any required dependencies
    init()
}

/// Protocol for services that can be reset to initial state
protocol ResettableService: ServiceProtocol {
    /// Reset the service to its initial state
    func reset()
}
