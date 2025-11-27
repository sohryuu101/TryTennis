import Foundation
import SwiftData

/// Service for managing session storage using SwiftData
class SessionStorageService {
    private var modelContext: ModelContext?
    
    init() {}
    
    /// Inject ModelContext from the view layer
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Save a new session
    func saveSession(
        totalAttempts: Int,
        successfulShots: Int,
        failedShots: Int,
        videoLocalIdentifier: String? = nil
    ) {
        guard let context = modelContext else {
            print("ModelContext not available")
            return
        }
        
        let newSession = Session(
            timestamp: Date(),
            totalAttempts: totalAttempts,
            successfulShots: successfulShots,
            failedShots: failedShots
        )
        newSession.videoLocalIdentifier = videoLocalIdentifier
        
        context.insert(newSession)
        
        do {
            try context.save()
            print("Session saved successfully")
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    /// Fetch all sessions
    func fetchAllSessions() -> [Session] {
        guard let context = modelContext else {
            return []
        }
        
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        do {
            let sessions = try context.fetch(descriptor)
            return sessions
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }
    
    /// Delete a session
    func deleteSession(_ session: Session) {
        guard let context = modelContext else {
            return
        }
        
        context.delete(session)
        
        do {
            try context.save()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}
