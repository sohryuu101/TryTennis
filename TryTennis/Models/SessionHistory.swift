import Foundation
import SwiftData

@Model
class SessionHistory {
    var id: UUID
    var duration: Int
    var success: Int
    var failure: Int
    var date: Date

    init(id: UUID = UUID(), duration: Int = 0, success: Int = 0, failure: Int = 0, date: Date = Date()) {
        self.id = id
        self.duration = duration
        self.success = success
        self.failure = failure
        self.date = date
    }
}
