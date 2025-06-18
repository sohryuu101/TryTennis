import Foundation
import SwiftUI
import SwiftData

class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    
    init(sessions: [Session]) {
        self.sessions = sessions
    }
    
    var todaySessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.timestamp) }
    }
    var past7DaysSessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter {
            !calendar.isDateInToday($0.timestamp) &&
            (calendar.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 8) < 7
        }
    }
    var past12MonthsSessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter {
            !(calendar.isDateInToday($0.timestamp) ||
              (calendar.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 400) < 7) &&
            (calendar.dateComponents([.month], from: $0.timestamp, to: Date()).month ?? 13) < 12
        }
    }
}
