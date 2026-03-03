import SwiftUI

/// Primary button with spring animation and haptic feedback
/// Use for main CTAs like "Start", "Submit", etc.
struct PrimaryButton: View {
    let title: String
    let icon: Image?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    // Style customization
    var backgroundColor: Color = Token.accent500.swiftUIColor
    var foregroundColor: Color = Token.white.swiftUIColor
    var height: CGFloat = 50

    init(
        _ title: String,
        icon: Image? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        backgroundColor: Color = Token.accent500.swiftUIColor,
        height: CGFloat = 50,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        icon
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(foregroundColor)
                    }

                    Text(title.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(isDisabled ? backgroundColor.opacity(0.4) : backgroundColor)
            .cornerRadius(height / 2)
        }
        .buttonStyle(ButtonPressAnimationStyle())
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Button Press Animation Style

struct ButtonPressAnimationStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Convenience Initializers

extension PrimaryButton {
    /// Creates a button with an icon
    static func icon(_ title: String, icon: Image, action: @escaping () -> Void) -> PrimaryButton {
        PrimaryButton(title, icon: icon, action: action)
    }

    /// Creates a loading button
    static func loading(_ title: String, action: @escaping () -> Void) -> PrimaryButton {
        PrimaryButton(title, isLoading: true, action: action)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PrimaryButton("Start Analyzing") {
            print("Tapped!")
        }

        PrimaryButton.icon("Start", icon: TryTennisIcon.playFill.swiftUIImage) {
            print("Tapped with icon!")
        }

        PrimaryButton("Loading", isLoading: true) {
            print("Disabled")
        }

        PrimaryButton("Disabled", isDisabled: true) {
            print("Won't tap")
        }

        PrimaryButton(
            "Custom Color",
            backgroundColor: Token.primary500.swiftUIColor
        ) {
            print("Custom color!")
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
