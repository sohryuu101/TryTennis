import Foundation

// MARK: - Watch Message Protocol

/// Protocol for watch messages to ensure type-safety
protocol WatchMessage: Encodable {
    var type: String { get }
    var timestamp: TimeInterval { get }
    var id: String { get }
}

// MARK: - Message Types

enum WatchMessageType: String {
    case shotFeedback = "shotFeedback"
    case sessionEnded = "sessionEnded"
    case notInFrame = "notInFrame"
    case backInFrame = "backInFrame"
    case liveAnalysisStarted = "liveAnalysisStarted"
}

// MARK: - Shot Feedback Message

struct ShotFeedbackMessage: WatchMessage {
    let type: String = WatchMessageType.shotFeedback.rawValue
    let angle: String
    let isSuccessful: Bool
    let timestamp: TimeInterval
    let id: String

    init(angle: String, isSuccessful: Bool) {
        self.angle = angle
        self.isSuccessful = isSuccessful
        self.timestamp = Date().timeIntervalSince1970
        self.id = UUID().uuidString
    }

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "angle": angle,
            "isSuccessful": isSuccessful,
            "timestamp": timestamp,
            "id": id
        ]
    }
}

// MARK: - Session Ended Message

struct SessionEndedMessage: WatchMessage {
    let type: String = WatchMessageType.sessionEnded.rawValue
    let timestamp: TimeInterval
    let id: String

    init() {
        self.timestamp = Date().timeIntervalSince1970
        self.id = UUID().uuidString
    }

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "timestamp": timestamp,
            "id": id
        ]
    }
}

// MARK: - Not In Frame Message

struct NotInFrameMessage: WatchMessage {
    let type: String = WatchMessageType.notInFrame.rawValue
    let timestamp: TimeInterval
    let id: String

    init() {
        self.timestamp = Date().timeIntervalSince1970
        self.id = UUID().uuidString
    }

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "timestamp": timestamp,
            "id": id
        ]
    }
}

// MARK: - Back In Frame Message

struct BackInFrameMessage: WatchMessage {
    let type: String = WatchMessageType.backInFrame.rawValue
    let timestamp: TimeInterval
    let id: String

    init() {
        self.timestamp = Date().timeIntervalSince1970
        self.id = UUID().uuidString
    }

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "timestamp": timestamp,
            "id": id
        ]
    }
}

// MARK: - Live Analysis Started Message

struct LiveAnalysisStartedMessage: WatchMessage {
    let type: String = WatchMessageType.liveAnalysisStarted.rawValue
    let timestamp: TimeInterval
    let id: String

    init() {
        self.timestamp = Date().timeIntervalSince1970
        self.id = UUID().uuidString
    }

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "timestamp": timestamp,
            "id": id
        ]
    }
}

// MARK: - Message Factory

enum WatchMessageFactory {
    static func createShotFeedback(angle: String, isSuccessful: Bool) -> [String: Any] {
        return ShotFeedbackMessage(angle: angle, isSuccessful: isSuccessful).toDictionary()
    }

    static func createSessionEnded() -> [String: Any] {
        return SessionEndedMessage().toDictionary()
    }

    static func createNotInFrame() -> [String: Any] {
        return NotInFrameMessage().toDictionary()
    }

    static func createBackInFrame() -> [String: Any] {
        return BackInFrameMessage().toDictionary()
    }

    static func createLiveAnalysisStarted() -> [String: Any] {
        return LiveAnalysisStartedMessage().toDictionary()
    }
}
