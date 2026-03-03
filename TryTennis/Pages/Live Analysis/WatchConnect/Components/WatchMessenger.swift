import Foundation
import WatchConnectivity

/// Handles sending messages to Apple Watch with retry and multiple delivery strategies
class WatchMessenger {

    // MARK: - Properties

    private let maxRetries = 2
    private var retryCount = 0
    private let retryInterval: TimeInterval = 1.0
    private var activationAttempts = 0
    private let maxActivationAttempts = 3

    private var messageQueue: WatchMessageQueue
    private var connectionHealth: WatchConnectionHealth

    // Throttling
    private var lastShotFeedbackTime: Date = Date.distantPast
    private let shotFeedbackThrottle: TimeInterval = 0.3

    // MARK: - Initialization

    init(messageQueue: WatchMessageQueue, connectionHealth: WatchConnectionHealth) {
        self.messageQueue = messageQueue
        self.connectionHealth = connectionHealth
        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueuedMessage),
            name: .watchMessageQueueDequeued,
            object: nil
        )
    }

    @objc private func handleQueuedMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? [String: Any] else { return }
        sendMessageOptimized(message)
    }

    // MARK: - Public API

    /// Send shot feedback with throttling
    func sendShotFeedback(angle: String, isSuccessful: Bool) {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping shot feedback.")
            return
        }

        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastShotFeedbackTime) > shotFeedbackThrottle else {
            print("Shot feedback throttled")
            return
        }
        lastShotFeedbackTime = currentTime

        let message = WatchMessageFactory.createShotFeedback(
            angle: angle,
            isSuccessful: isSuccessful
        )
        print("Sending shot feedback: \(angle), successful: \(isSuccessful)")
        sendMessage(message)
    }

    /// Send immediate shot feedback (bypasses throttle)
    func sendImmediateShotFeedback(angle: String, isSuccessful: Bool) {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping immediate shot feedback.")
            return
        }

        let now = Date()
        if now.timeIntervalSince(lastShotFeedbackTime) < shotFeedbackThrottle {
            print("Shot feedback throttled - too soon since last feedback")
            return
        }
        lastShotFeedbackTime = now

        let message = WatchMessageFactory.createShotFeedback(
            angle: angle,
            isSuccessful: isSuccessful
        )
        print("Sending immediate shot feedback: \(angle), successful: \(isSuccessful)")
        sendMessageOptimized(message)
    }

    /// Send session ended notification
    func sendSessionEnded() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping session ended feedback.")
            return
        }

        let message = WatchMessageFactory.createSessionEnded()
        sendMessage(message)
    }

    /// Send not-in-frame notification
    func sendNotInFrame() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping not-in-frame feedback.")
            return
        }

        let message = WatchMessageFactory.createNotInFrame()
        print("Sending not-in-frame feedback to watch")
        sendMessage(message)
    }

    /// Send back-in-frame notification
    func sendBackInFrame() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping back-in-frame feedback.")
            return
        }

        let message = WatchMessageFactory.createBackInFrame()
        print("Sending back-in-frame feedback to watch")
        sendMessage(message)
    }

    /// Send live analysis started notification
    func sendLiveAnalysisStarted() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping live analysis start notification.")
            return
        }

        let message = WatchMessageFactory.createLiveAnalysisStarted()
        print("Sending live analysis started notification to watch")
        sendMessage(message)
    }

    // MARK: - Message Sending

    private func sendMessage(_ message: [String: Any]) {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping message send.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard WCSession.default.activationState == .activated else {
                print("WCSession not activated. Current state: \(WCSession.default.activationState.rawValue)")
                self?.messageQueue.enqueue(message)

                if self?.activationAttempts ?? 0 < (self?.maxActivationAttempts ?? 0) {
                    DispatchQueue.main.async {
                        self?.activationAttempts += 1
                        print("Attempting to activate WCSession (attempt \(self?.activationAttempts ?? 0)/\(self?.maxActivationAttempts ?? 0))")
                        WCSession.default.activate()
                    }
                }
                return
            }

            self?.sendMessageOptimized(message)
        }
    }

    private func sendMessageOptimized(_ message: [String: Any]) {
        let session = WCSession.default

        if session.isReachable {
            sendMessageToWatch(message)
        } else {
            useQueuedDelivery(message: message)
        }
    }

    private func sendMessageToWatch(_ message: [String: Any]) {
        print("Attempting to send message to watch: \(message)")

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            print("Message sent successfully to watch. Reply: \(reply)")

            DispatchQueue.main.async {
                self?.connectionHealth.recordSuccessfulMessage()
                self?.retryCount = 0
                self?.activationAttempts = 0
            }

            if let status = reply["status"] as? String, status == "error" {
                print("Watch responded with error status")
                if let errorMessage = reply["message"] as? String {
                    print("Watch error message: \(errorMessage)")
                }
            }
        }) { [weak self] error in
            print("Error sending message to watch: \(error.localizedDescription)")
            print("Error code: \((error as NSError).code)")

            if let messageType = message["type"] as? String, messageType == "shotFeedback" {
                print("Trying alternative delivery for shot feedback")
                self?.useQueuedDelivery(message: message)
            } else {
                self?.handleSendError(message: message, error: error)
            }
        }
    }

    private func handleSendError(message: [String: Any], error: Error) {
        if retryCount < maxRetries {
            retryCount += 1
            print("Retrying message send (attempt \(retryCount)/\(maxRetries))")

            DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) { [weak self] in
                self?.sendMessageToWatch(message)
            }
        } else {
            print("Failed to send message after \(maxRetries) attempts")
            retryCount = 0
            useQueuedDelivery(message: message)
        }
    }

    private func useQueuedDelivery(message: [String: Any]) {
        WCSession.default.transferUserInfo(message)
        print("Message queued via transferUserInfo")

        do {
            try WCSession.default.updateApplicationContext(message)
            print("Message sent via application context")
        } catch {
            print("Failed to send via application context: \(error.localizedDescription)")
        }
    }

    // MARK: - Queue Management

    func processQueuedMessages() {
        messageQueue.processQueue(sessionActivationState: WCSession.default.activationState)
    }

    func clearQueue() {
        messageQueue.clear()
        retryCount = 0
        activationAttempts = 0
    }
}
