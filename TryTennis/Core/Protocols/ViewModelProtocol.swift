import Foundation
import Combine

/// Base protocol for all ViewModels in the app
/// Ensures ViewModels are observable and follow consistent patterns
protocol ViewModelProtocol: ObservableObject {
    /// Called when the view appears
    func onAppear()
    
    /// Called when the view disappears
    func onDisappear()
}

// Default implementations for optional behavior
extension ViewModelProtocol {
    func onAppear() {}
    func onDisappear() {}
}
