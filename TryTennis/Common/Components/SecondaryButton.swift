import SwiftUI

/// Secondary button with glassmorphism effect
/// Use for secondary actions like "Cancel", "Skip", etc.
struct SecondaryButton: View {
    let title: String
    let icon: Image?
    let action: () -> Void
    var isDisabled: Bool = false

    // Style customization
    var height: CGFloat = 44
    var horizontalPadding: CGFloat = 20

    init(
        _ title: String,
        icon: Image? = nil,
        isDisabled: Bool = false,
        height: CGFloat = 44,
        horizontalPadding: CGFloat = 20,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    icon
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .frame(height: height)
            .background(backgroundView)
            .cornerRadius(12)
        }
        .buttonStyle(ButtonPressAnimationStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var backgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var textColor: Color {
        isDisabled ? Token.gray500.swiftUIColor : Token.white.swiftUIColor
    }

    private var iconColor: Color {
        isDisabled ? Token.gray500.swiftUIColor : Token.gray300.swiftUIColor
    }

    private var borderColor: Color {
        isDisabled ? Token.gray500.swiftUIColor.opacity(0.2) : Token.white.swiftUIColor.opacity(0.15)
    }
}

// MARK: - Convenience Initializers

extension SecondaryButton {
    /// Creates a button with an icon
    static func icon(_ title: String, icon: Image, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title, icon: icon, action: action)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SecondaryButton("Cancel") {
            print("Cancelled")
        }

        SecondaryButton.icon("Skip", icon: TryTennisIcon.arrowRight.swiftUIImage) {
            print("Skipped")
        }

        SecondaryButton("Disabled", isDisabled: true) {
            print("Won't tap")
        }

        HStack(spacing: 10) {
            SecondaryButton("Small", horizontalPadding: 12) {
                print("Small")
            }

            SecondaryButton.icon("Delete", icon: TryTennisIcon.trashFill.swiftUIImage) {
                print("Delete")
            }
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
