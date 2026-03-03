import Foundation
import WatchConnectivity

/// Manages message queuing for Watch connectivity when session is not ready
class WatchMessageQueue {

    // MARK: - Properties

    private var messageQueue: [[String: Any]] = []
    private var retryTimer: Timer?
    private let maxRetryInterval: TimeInterval = 1.0

    // MARK: - Queue Management

    /// Enqueue a message for later delivery
    func enqueue(_ message: [String: Any]) {
        messageQueue.append(message)
        print("Message queued. Queue size: \(messageQueue.count)")
    }

    /// Process all queued messages when session becomes ready
    func processQueue(sessionActivationState: WCSessionActivationState) {
        guard !messageQueue.isEmpty else { return }

        if sessionActivationState == .activated {
            let messagesToSend = messageQueue
            messageQueue.removeAll()

            print("Processing \(messagesToSend.count) queued messages")

            // Return messages to be sent by messenger
            messagesToSend.forEach { message in
                NotificationCenter.default.post(
                    name: .watchMessageQueueDequeued,
                    object: nil,
                    userInfo: ["message": message]
                )
            }
        } else {
            // Schedule retry
            scheduleRetry()
        }
    }

    /// Clear all queued messages
    func clear() {
        messageQueue.removeAll()
        retryTimer?.invalidate()
        retryTimer = nil
        print("Message queue cleared")
    }

    /// Get current queue size
    var queueSize: Int {
        return messageQueue.count
    }

    // MARK: - Private Methods

    private func scheduleRetry() {
        guard retryTimer == nil else { return }

        retryTimer = Timer.scheduledTimer(withTimeInterval: maxRetryInterval, repeats: false) { [weak self] _ in
            self?.retryTimer = nil
            NotificationCenter.default.post(name: .watchMessageQueueRetry, object: nil)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let watchMessageQueueDequeued = Notification.Name("watchMessageQueueDequeued")
    static let watchMessageQueueRetry = Notification.Name("watchMessageQueueRetry")
}
