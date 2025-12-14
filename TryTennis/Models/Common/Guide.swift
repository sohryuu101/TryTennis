import SwiftUI

/// Generic guide item model used across the app
struct Guide: Identifiable {
    var id = UUID()
    var image: Icon
    var title: String
}
