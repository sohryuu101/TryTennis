import SwiftUI

class SplashScreenViewModel: ObservableObject {
    @Published private(set) var isSplashScreenActive: Bool = true
    
    func dismissSplashScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeOut(duration: 1)) {
                self.isSplashScreenActive = false
            }
        }
    }
}
