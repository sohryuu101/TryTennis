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

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}
