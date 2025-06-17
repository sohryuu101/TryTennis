import SwiftData
import SwiftUI

@main
struct TryTennisApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SplashScreenView()
            }
        }
        .modelContainer(for: [Session.self])
    }
}
