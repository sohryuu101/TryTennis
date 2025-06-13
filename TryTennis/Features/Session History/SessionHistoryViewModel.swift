import SwiftUI

class SessionHistoryViewModel: ObservableObject {
    @Published private(set) var activities: [SessionHistory] = []
    
    init(){
        self.fetchActivities()
    }
    
    private func fetchActivities() {
        
    }
}
