import Foundation
import UserNotifications
import WatchConnectivity

/// Facade for Watch connectivity using refactored components
/// Reduced from 461 lines to ~150 lines by extracting components
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Published State

    @Published var isReachable = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?

    // MARK: - Components

    private let messenger: WatchMessenger
    private let messageQueue: WatchMessageQueue
    private let connectionHealth: WatchConnectionHealth

    // MARK: - Connection State

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case failed
    }

    // MARK: - Initialization

    private override init() {
        // Initialize components
        self.messageQueue = WatchMessageQueue()
        self.connectionHealth = WatchConnectionHealth()
        self.messenger = WatchMessenger(
            messageQueue: messageQueue,
            connectionHealth: connectionHealth
        )

        super.init()

        setupWatchConnectivity()
        setupNotifications()
        setupComponentObservers()
        connectionHealth.startMonitoring()
    }

    // MARK: - Setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WCSession is not supported on this device")
            connectionStatus = .failed
            lastError = "WCSession not supported"
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        connectionStatus = .connecting
        print("WCSession activation started...")
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    private func setupComponentObservers() {
        // Handle reconnection requests from health monitor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReconnectionRequest),
            name: .watchConnectionShouldReconnect,
            object: nil
        )

        // Handle queue retry requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueueRetry),
            name: .watchMessageQueueRetry,
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc private func handleReconnectionRequest() {
        forceReconnect()
    }

    @objc private func handleQueueRetry() {
        messenger.processQueuedMessages()
    }

    // MARK: - Public API (Delegates to Messenger)

    func sendShotFeedback(angle: String, isSuccessful: Bool) {
        messenger.sendShotFeedback(angle: angle, isSuccessful: isSuccessful)
    }

    func sendImmediateShotFeedback(angle: String, isSuccessful: Bool) {
        messenger.sendImmediateShotFeedback(angle: angle, isSuccessful: isSuccessful)
    }

    func sendSessionEndedFeedback() {
        messenger.sendSessionEnded()
    }

    func sendNotInFrameFeedback() {
        messenger.sendNotInFrame()
    }

    func sendBackInFrameFeedback() {
        messenger.sendBackInFrame()
    }

    func sendLiveAnalysisStartedNotification() {
        messenger.sendLiveAnalysisStarted()
    }

    // MARK: - Queue & Connection Management

    func clearMessageQueue() {
        messenger.clearQueue()
    }

    func forceReconnect() {
        print("Force reconnecting WCSession...")
        connectionStatus = .connecting
        messenger.clearQueue()
        WCSession.default.activate()
    }

    func getConnectionDebugInfo() -> String {
        let session = WCSession.default
        return """
        WCSession Debug Info:
        - Supported: \(WCSession.isSupported())
        - Activation State: \(session.activationState.rawValue)
        - Is Paired: \(session.isPaired)
        - Is Reachable: \(session.isReachable)
        - Connection Status: \(connectionStatus)
        - Queue Size: \(messageQueue.queueSize)
        - Last Error: \(lastError ?? "None")
        - Time Since Last Success: \(connectionHealth.timeSinceLastSuccess.rounded())s
        """
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        connectionHealth.stopMonitoring()
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                self.connectionStatus = .failed
            } else {
                switch activationState {
                case .activated:
                    if session.isPaired {
                        self.connectionStatus = .connected
                        self.isReachable = session.isReachable
                        print("WCSession activated successfully. Paired: \(session.isPaired), Reachable: \(session.isReachable)")
                        // Process queued messages using messenger
                        self.messenger.processQueuedMessages()
                    } else {
                        self.connectionStatus = .failed
                        self.isReachable = false
                        self.lastError = "Apple Watch is not paired"
                        print("WCSession activated but Apple Watch is not paired")
                    }
                case .inactive:
                    self.connectionStatus = .disconnected
                    self.isReachable = false
                    print("WCSession became inactive")
                case .notActivated:
                    self.connectionStatus = .failed
                    self.isReachable = false
                    print("WCSession failed to activate")
                @unknown default:
                    self.connectionStatus = .disconnected
                    self.isReachable = false
                }
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let wasReachable = self.isReachable
            self.isReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")

            if session.isReachable && !wasReachable {
                print("Watch became reachable, processing queued messages")
                self.messenger.processQueuedMessages()
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("Received user info: \(userInfo)")
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error = error {
            print("User info transfer failed: \(error.localizedDescription)")
        } else {
            print("User info transfer completed successfully")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context: \(applicationContext)")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isReachable = false
            print("WCSession became inactive")
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated, reactivating...")
        WCSession.default.activate()
    }
    #endif
}
