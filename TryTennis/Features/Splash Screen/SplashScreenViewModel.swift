import SwiftUI

class SplashScreenViewModel: ObservableObject {
    @Published private(set) var isSplashScreenActive: Bool = true
    @Published private(set) var isOnboardingActive: Bool = true
    
    func dismissSplashScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeOut(duration: 1)) {
                self.isSplashScreenActive = false
            }
        }
    }
    
    func changeOnboarding() {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.3)) {
                self.isOnboardingActive = false
            }
        }
    }
}
