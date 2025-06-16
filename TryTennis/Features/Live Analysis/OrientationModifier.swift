import SwiftUI

struct OrientationModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask

    func body(content: Content) -> some View {
        content
            .onAppear {
                AppDelegate.orientation = orientation
            }
            .onDisappear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AppDelegate.orientation = .portrait
                }
            }
    }
}

extension View {
    func orientationLock(_ orientation: UIInterfaceOrientationMask) -> some View {
        self.modifier(OrientationModifier(orientation: orientation))
    }
} 