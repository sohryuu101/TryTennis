import SwiftUI

/// ViewModel for Splash Screen
class SplashScreenViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published private(set) var isSplashScreenActive: Bool = true
    
    // MARK: - Lifecycle
    override func onAppear() {
        super.onAppear()
    }
    
    // MARK: - Methods
    func dismissSplashScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeOut(duration: 1)) {
                self.isSplashScreenActive = false
            }
        }
    }
}
