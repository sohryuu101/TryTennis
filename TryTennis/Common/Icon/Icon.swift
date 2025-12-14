import Foundation
import UIKit
import SwiftUI

final class Icon {
    let iconName: String
    let isSystem: Bool
    
    init(iconName: String, isSystem: Bool = false) {
        self.iconName = iconName
        self.isSystem = isSystem
    }
    
    var image: UIImage {
        if isSystem {
            if let image = UIImage(systemName: iconName) {
                return image
            }
            print("Warning: System icon \(iconName) not found")
            return UIImage()
        } else {
            if let image = UIImage(named: iconName) {
                return image
            }
            assertionFailure("image \(iconName) can't be loaded")
            return UIImage()
        }
    }
    
    var swiftUIImage: Image {
        if isSystem {
            return Image(systemName: iconName)
        } else {
            return Image(iconName)
        }
    }
    
    func getImageWithTintColor(_ color: UIColor) -> UIImage {
        let imageTemplate: UIImage = image.withRenderingMode(.alwaysOriginal)
        return imageTemplate.withTintColor(color)
    }
}