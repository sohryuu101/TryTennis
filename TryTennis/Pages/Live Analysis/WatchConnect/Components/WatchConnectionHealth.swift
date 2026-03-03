import Foundation
import WatchConnectivity

/// Monitors Watch connection health and triggers reconnection if needed
class WatchConnectionHealth {

    // MARK: - Properties

    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 5.0
    private var lastSuccessfulMessageTime: Date = Date.distantPast
    private let unhealthyThreshold: TimeInterval = 30.0

    // MARK: - Health Monitoring

    /// Start monitoring connection health
    func startMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
        print("Watch connection health monitoring started")
    }

    /// Stop monitoring connection health
    func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        print("Watch connection health monitoring stopped")
    }

    /// Check if connection is healthy and reconnect if needed
    func checkHealth() {
        let session = WCSession.default
        let timeSinceLastSuccess = Date().timeIntervalSince(lastSuccessfulMessageTime)

        // If no successful messages in threshold time and session should be working
        if timeSinceLastSuccess > unhealthyThreshold &&
           session.activationState == .activated &&
           !session.isReachable {
            print("Connection health check: Unhealthy - no successful messages in \(timeSinceLastSuccess.rounded())s")
            triggerReconnect()
        }
    }

    /// Call this when a message is successfully sent/received
    func recordSuccessfulMessage() {
        lastSuccessfulMessageTime = Date()
    }

    /// Get time since last successful message
    var timeSinceLastSuccess: TimeInterval {
        return Date().timeIntervalSince(lastSuccessfulMessageTime)
    }

    // MARK: - Reconnection

    private func triggerReconnect() {
        print("Triggering Watch reconnection...")
        NotificationCenter.default.post(name: .watchConnectionShouldReconnect, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let watchConnectionShouldReconnect = Notification.Name("watchConnectionShouldReconnect")
}
