import SwiftUI

extension View {
    func orientationLock(_ orientation: UIInterfaceOrientationMask) -> some View {
        self.modifier(OrientationModifier(orientation: orientation))
    }
    
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}
