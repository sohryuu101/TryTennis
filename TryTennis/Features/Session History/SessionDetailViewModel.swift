import Foundation
import SwiftData
import SwiftUI

@Observable
class SessionDetailViewModel {
    let session: Session
    
    init(session: Session) {
        self.session = session
    }
} 
