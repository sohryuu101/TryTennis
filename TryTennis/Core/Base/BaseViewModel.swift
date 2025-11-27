import Foundation
import Combine

/// Base class for ViewModels providing common functionality
/// All ViewModels should inherit from this class
class BaseViewModel: ObservableObject, ViewModelProtocol {
    // Set to store Combine subscriptions
    var cancellables = Set<AnyCancellable>()
    
    init() {
        // Base initialization
    }
    
    func onAppear() {
        // Override in subclasses if needed
    }
    
    func onDisappear() {
        // Override in subclasses if needed
    }
    
    deinit {
        cancellables.removeAll()
    }
}
