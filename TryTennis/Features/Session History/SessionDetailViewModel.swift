import Foundation
import SwiftUI
import SwiftData

@Observable
class SessionDetailViewModel {
    let session: Session
    
    init(session: Session) {
        self.session = session
    }
} 