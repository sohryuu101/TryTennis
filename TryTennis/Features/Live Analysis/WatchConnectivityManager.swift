import Foundation
import WatchConnectivity
import UserNotifications

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var isReachable = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    private var messageQueue: [[String: Any]] = []
    private var retryTimer: Timer?
    private let maxRetries = 2
    private var retryCount = 0
    private let retryInterval: TimeInterval = 1.0
    private var activationAttempts = 0
    private let maxActivationAttempts = 3
    private var lastShotFeedbackTime: Date = Date.distantPast
    private let shotFeedbackThrottle: TimeInterval = 0.3
    private var connectionHealthTimer: Timer?
    private var lastSuccessfulMessageTime: Date = Date.distantPast
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case failed
    }
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupNotifications()
        startConnectionHealthMonitoring()
    }
    
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
    
    private func startConnectionHealthMonitoring() {
        connectionHealthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkConnectionHealth()
        }
    }
    
    private func checkConnectionHealth() {
        let session = WCSession.default
        let timeSinceLastSuccess = Date().timeIntervalSince(lastSuccessfulMessageTime)
        
        if timeSinceLastSuccess > 30 && session.activationState == .activated && !session.isReachable {
            print("Connection health check: No successful messages in 30s, attempting reconnection")
            forceReconnect()
        }
    }
    
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
        
        let message: [String: Any] = [
            "type": "shotFeedback",
            "angle": angle,
            "isSuccessful": isSuccessful,
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        
        print("Sending shot feedback: \(angle), successful: \(isSuccessful)")
        sendMessage(message)
    }
    
    func sendImmediateShotFeedback(angle: String, isSuccessful: Bool) {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping shot feedback.")
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastShotFeedbackTime) < shotFeedbackThrottle {
            print("Shot feedback throttled - too soon since last feedback")
            return
        }
        lastShotFeedbackTime = now
        
        let message: [String: Any] = [
            "type": "shotFeedback",
            "angle": angle,
            "isSuccessful": isSuccessful,
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        
        print("Sending immediate shot feedback: \(angle), successful: \(isSuccessful)")
        
        sendMessageOptimized(message)
    }
    
    func sendSessionEndedFeedback() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping session ended feedback.")
            return
        }
        
        let message: [String: Any] = [
            "type": "sessionEnded",
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        
        sendMessage(message)
    }
    
    func sendNotInFrameFeedback() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping not-in-frame feedback.")
            return
        }
        let message: [String: Any] = [
            "type": "notInFrame",
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        print("Sending not-in-frame feedback to watch")
        sendMessage(message)
    }
    
    func sendBackInFrameFeedback() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping back-in-frame feedback.")
            return
        }
        let message: [String: Any] = [
            "type": "backInFrame",
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        print("Sending back-in-frame feedback to watch")
        sendMessage(message)
    }
    
    func sendLiveAnalysisStartedNotification() {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping live analysis start notification.")
            return
        }
        let message: [String: Any] = [
            "type": "liveAnalysisStarted",
            "timestamp": Date().timeIntervalSince1970,
            "id": UUID().uuidString
        ]
        print("Sending live analysis started notification to watch")
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard WCSession.default.isPaired else {
            print("Apple Watch is not paired. Skipping message send.")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard WCSession.default.activationState == .activated else {
                print("WCSession not activated. Current state: \(WCSession.default.activationState.rawValue)")
                DispatchQueue.main.async {
                    self.messageQueue.append(message)
                    print("Message queued. Queue size: \(self.messageQueue.count)")
                }
                
                if self.activationAttempts < self.maxActivationAttempts {
                    DispatchQueue.main.async {
                        self.activationAttempts += 1
                        print("Attempting to activate WCSession (attempt \(self.activationAttempts)/\(self.maxActivationAttempts))")
                        WCSession.default.activate()
                    }
                }
                return
            }
            
            self.sendMessageOptimized(message)
        }
    }
    
    private func sendMessageOptimized(_ message: [String: Any]) {
        let session = WCSession.default
        
        if let messageType = message["type"] as? String, messageType == "shotFeedback" {
            if session.isReachable {
                sendMessageToWatch(message)
            } else {
                useQueuedDelivery(message: message)
            }
        } else {
            if session.isReachable {
                sendMessageToWatch(message)
            } else {
                useQueuedDelivery(message: message)
            }
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
    
    private func sendMessageToWatch(_ message: [String: Any]) {
        print("Attempting to send message to watch: \(message)")
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("Message sent successfully to watch. Reply: \(reply)")
            
            DispatchQueue.main.async {
                self.lastSuccessfulMessageTime = Date()
                self.retryCount = 0
                self.activationAttempts = 0
            }
            
            if let status = reply["status"] as? String, status == "error" {
                print("Watch responded with error status")
                if let errorMessage = reply["message"] as? String {
                    print("Watch error message: \(errorMessage)")
                }
            }
        }) { error in
            print("Error sending message to watch: \(error.localizedDescription)")
            print("Error code: \((error as NSError).code)")
            
            if let messageType = message["type"] as? String, messageType == "shotFeedback" {
                print("Trying alternative delivery for shot feedback")
                self.useQueuedDelivery(message: message)
            } else {
                self.handleSendError(message: message, error: error)
            }
        }
    }
    
    private func handleSendError(message: [String: Any], error: Error) {
        if retryCount < maxRetries {
            retryCount += 1
            print("Retrying message send (attempt \(retryCount)/\(maxRetries))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) {
                self.sendMessageToWatch(message)
            }
        } else {
            print("Failed to send message after \(maxRetries) attempts")
            retryCount = 0
            
            useQueuedDelivery(message: message)
        }
    }
    
    private func processMessageQueue() {
        guard !messageQueue.isEmpty else { return }
        
        if WCSession.default.activationState == .activated {
            let messagesToSend = messageQueue
            messageQueue.removeAll()
            
            print("Processing \(messagesToSend.count) queued messages")
            for message in messagesToSend {
                sendMessageOptimized(message)
            }
        } else {
            if retryTimer == nil {
                retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    self.retryTimer = nil
                    self.processMessageQueue()
                }
            }
        }
    }
    
    private func sendLocalNotification(for message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch type {
        case "shotFeedback":
            guard let angle = message["angle"] as? String,
                  let isSuccessful = message["isSuccessful"] as? Bool else { return }
            content.title = isSuccessful ? "Great Shot!" : "Keep Trying"
            content.body = "Racquet angle: \(angle)"
            content.categoryIdentifier = "SHOT_FEEDBACK"
        case "sessionEnded":
            content.title = "Session Complete"
            content.body = "Your tennis session has ended"
            content.categoryIdentifier = "SESSION_ENDED"
        case "notInFrame":
            content.title = "Warning"
            content.body = "You are not in frame!"
            content.categoryIdentifier = "NOT_IN_FRAME"
        case "backInFrame":
            content.title = "Info"
            content.body = "You are back in frame!"
            content.categoryIdentifier = "BACK_IN_FRAME"
        case "liveAnalysisStarted":
            content.title = "Live Analysis Started"
            content.body = "Tap to open TryTennis on your watch."
            content.categoryIdentifier = "LIVE_ANALYSIS_START"
        default:
            return
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func clearMessageQueue() {
        messageQueue.removeAll()
        retryTimer?.invalidate()
        retryTimer = nil
        retryCount = 0
    }
    
    func forceReconnect() {
        print("Force reconnecting WCSession...")
        activationAttempts = 0
        connectionStatus = .connecting
        clearMessageQueue()
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
        - Queue Size: \(messageQueue.count)
        - Activation Attempts: \(activationAttempts)
        - Last Error: \(lastError ?? "None")
        - Time Since Last Success: \(Date().timeIntervalSince(lastSuccessfulMessageTime).rounded())s
        """
    }
    
    deinit {
        connectionHealthTimer?.invalidate()
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
                        self.activationAttempts = 0
                        print("WCSession activated successfully. Paired: \(session.isPaired), Reachable: \(session.isReachable)")
                        self.processMessageQueue()
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
                self.processMessageQueue()
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
