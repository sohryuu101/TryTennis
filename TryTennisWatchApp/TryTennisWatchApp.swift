import SwiftUI
import WatchKit
import WatchConnectivity

@main
struct TryTennisWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(connectivityManager)
        }
    }
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var lastShotFeedback: ShotFeedback?
    @Published var feedbackHistory: [ShotFeedback] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    enum ConnectionStatus {
        case disconnected, connecting, connected, failed
    }
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("Watch: WCSession is not supported")
            connectionStatus = .failed
            lastError = "WCSession not supported"
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
        connectionStatus = .connecting
        print("Watch: WCSession activation started...")
    }
    
    private func handleShotFeedback(_ message: [String: Any]) {
        // Handle both "isSuccessful" and "isSuccessful" key variations
        guard let angle = message["angle"] as? String,
              let isSuccessful = (message["isSuccessful"] as? Bool) ?? (message["successful"] as? Bool) else {
            print("Watch: Invalid shot feedback message: \(message)")
            return
        }
        
        let feedback = ShotFeedback(angle: angle, isSuccessful: isSuccessful)
        
        DispatchQueue.main.async {
            print("Watch: Updating UI with shot feedback: \(angle), successful: \(isSuccessful)")
            self.lastShotFeedback = feedback
            self.feedbackHistory.append(feedback)
            
            if self.feedbackHistory.count > 10 {
                self.feedbackHistory.removeFirst()
            }
            
            self.provideHapticFeedback(for: feedback)
            WKInterfaceDevice.current().play(.notification)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.lastShotFeedback == feedback {
                self.lastShotFeedback = nil
            }
        }
    }
    
    private func handleSessionEnded(_ message: [String: Any]) {
        print("Watch: Session ended message received")
        DispatchQueue.main.async {
            WKInterfaceDevice.current().play(.success)
            self.lastShotFeedback = ShotFeedback(angle: "Session Complete", isSuccessful: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastShotFeedback = nil
            }
        }
    }
    
    private func provideHapticFeedback(for feedback: ShotFeedback) {
        if feedback.isSuccessful {
            WKInterfaceDevice.current().play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                WKInterfaceDevice.current().play(.click)
            }
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    func clearHistory() {
        feedbackHistory.removeAll()
        lastShotFeedback = nil
    }
    
    func forceReconnect() {
        print("Watch: Force reconnecting...")
        connectionStatus = .connecting
        WCSession.default.activate()
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Watch: WCSession activation failed with error: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                self.connectionStatus = .failed
            } else {
                switch activationState {
                case .activated:
                    self.connectionStatus = .connected
                    print("Watch: WCSession activated successfully")
                case .inactive:
                    self.connectionStatus = .disconnected
                    print("Watch: WCSession became inactive")
                case .notActivated:
                    self.connectionStatus = .failed
                    print("Watch: WCSession failed to activate")
                @unknown default:
                    self.connectionStatus = .disconnected
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Watch: Received message: \(message)")
        guard let type = message["type"] as? String else {
            print("Watch: Invalid message type")
            return
        }
        
        switch type {
        case "shotFeedback":
            handleShotFeedback(message)
        case "sessionEnded":
            handleSessionEnded(message)
        default:
            print("Watch: Unknown message type: \(type)")
        }
    }
    
    // Handle transferUserInfo (queued delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("Watch: Received user info: \(userInfo)")
        
        guard let type = userInfo["type"] as? String else {
            print("Watch: Invalid user info type")
            return
        }
        
        switch type {
        case "shotFeedback":
            handleShotFeedback(userInfo)
        case "sessionEnded":
            handleSessionEnded(userInfo)
        default:
            print("Watch: Unknown user info type: \(type)")
        }
    }

    // Handle updateApplicationContext (immediate state update)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Watch: Received application context: \(applicationContext)")
        
        guard let type = applicationContext["type"] as? String else {
            print("Watch: Invalid application context type")
            return
        }
        
        switch type {
        case "shotFeedback":
            handleShotFeedback(applicationContext)
        case "sessionEnded":
            handleSessionEnded(applicationContext)
        default:
            print("Watch: Unknown application context type: \(type)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Watch: Received message with reply handler: \(message)")
        guard let type = message["type"] as? String else {
            print("Watch: Invalid message type")
            replyHandler(["status": "error", "message": "Invalid message type"])
            return
        }
        
        switch type {
        case "shotFeedback":
            handleShotFeedback(message)
            replyHandler(["status": "received", "type": "shotFeedback"])
        case "sessionEnded":
            handleSessionEnded(message)
            replyHandler(["status": "received", "type": "sessionEnded"])
        default:
            print("Watch: Unknown message type: \(type)")
            replyHandler(["status": "error", "message": "Unknown message type"])
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("Watch: Reachability changed: \(session.isReachable)")
        }
    }
}

struct ShotFeedback: Identifiable, Equatable {
    let id = UUID()
    let angle: String
    let isSuccessful: Bool
}

struct ContentView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(connectivityManager.connectionStatus == .connected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connectivityManager.connectionStatus == .connected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = connectivityManager.lastError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            if let feedback = connectivityManager.lastShotFeedback {
                VStack(spacing: 12) {
                    Image(systemName: feedback.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(feedback.isSuccessful ? .green : .red)
                        .font(.system(size: 50))
                    Text(feedback.angle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(feedback.isSuccessful ? "Great Shot!" : "Keep Trying")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.1)))
                .animation(.easeInOut(duration: 0.3), value: feedback.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tennis.racket")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("Ready for shots")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Start your session on iPhone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            
            if !connectivityManager.feedbackHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Shots").font(.headline)
                    ForEach(connectivityManager.feedbackHistory.suffix(5)) { feedback in
                        HStack {
                            Image(systemName: feedback.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(feedback.isSuccessful ? .green : .red)
                                .font(.caption)
                            Text(feedback.angle)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}
