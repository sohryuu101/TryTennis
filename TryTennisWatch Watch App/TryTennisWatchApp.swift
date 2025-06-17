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
    
    enum ConnectionStatus {
        case disconnected, connecting, connected, failed
    }
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            connectionStatus = .connecting
            print("Watch: Setting up connectivity...")
        } else {
            connectionStatus = .failed
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.connectionStatus = .connected
                print("Watch: Session activated successfully")
            case .inactive:
                self.connectionStatus = .disconnected
            case .notActivated:
                self.connectionStatus = .failed
            @unknown default:
                self.connectionStatus = .disconnected
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Watch: Received message: \(message)")
        guard let type = message["type"] as? String,
              type == "shotFeedback",
              let angle = message["angle"] as? String,
              let isSuccessful = message["isSuccessful"] as? Bool else {
            return
        }
        let feedback = ShotFeedback(angle: angle, isSuccessful: isSuccessful)
        DispatchQueue.main.async {
            self.lastShotFeedback = feedback
            self.feedbackHistory.append(feedback)
            if self.feedbackHistory.count > 10 {
                self.feedbackHistory.removeFirst()
            }
            WKInterfaceDevice.current().play(.notification)
            if isSuccessful {
                WKInterfaceDevice.current().play(.success)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.lastShotFeedback == feedback {
                self.lastShotFeedback = nil
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Watch: Received message with reply: \(message)")
        guard let type = message["type"] as? String,
              type == "shotFeedback",
              let angle = message["angle"] as? String,
              let isSuccessful = message["isSuccessful"] as? Bool else {
            replyHandler(["status": "error"])
            return
        }
        let feedback = ShotFeedback(angle: angle, isSuccessful: isSuccessful)
        DispatchQueue.main.async {
            self.lastShotFeedback = feedback
            self.feedbackHistory.append(feedback)
            if self.feedbackHistory.count > 10 {
                self.feedbackHistory.removeFirst()
            }
            WKInterfaceDevice.current().play(.notification)
            if isSuccessful {
                WKInterfaceDevice.current().play(.success)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
        replyHandler(["status": "received"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.lastShotFeedback == feedback {
                self.lastShotFeedback = nil
            }
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