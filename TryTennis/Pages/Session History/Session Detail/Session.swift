import Foundation
import SwiftData

@Model
final class Session {
    var timestamp: Date
    var totalAttempts: Int
    var successfulShots: Int
    var failedShots: Int
    var videoLocalIdentifier: String?
    var openRacquetTimestamp: Double?
    var closedRacquetTimestamp: Double?
    var optimalRacquetTimestamp: Double?

    init(timestamp: Date, totalAttempts: Int, successfulShots: Int, failedShots: Int) {
        self.timestamp = timestamp
        self.totalAttempts = totalAttempts
        self.successfulShots = successfulShots
        self.failedShots = failedShots
        self.videoLocalIdentifier = nil
        self.openRacquetTimestamp = nil
        self.closedRacquetTimestamp = nil
        self.optimalRacquetTimestamp = nil
    }
} 