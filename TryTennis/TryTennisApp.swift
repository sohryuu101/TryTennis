import SwiftUI
import SwiftData

@main
struct TryTennisApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
        .modelContainer(for: [SessionHistory.self])
    }
}
