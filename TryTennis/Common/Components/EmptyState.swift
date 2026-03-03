import SwiftUI

/// Empty state component for showing when no data is available
/// Includes illustration, title, description, and action button
struct EmptyState: View {
    let icon: Image?
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: Image? = nil,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon or illustration
            if let icon = icon {
                icon
                    .font(.system(size: 64))
                    .foregroundColor(Token.gray400.swiftUIColor)
                    .scaleEffect(1.0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.5)
                        .delay(0.1),
                        value: true
                    )
            }

            // Title
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Token.white.swiftUIColor)
                .multilineTextAlignment(.center)

            // Message
            Text(message)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Token.gray400.swiftUIColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Action button (optional)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Token.accent500.swiftUIColor)
                        .cornerRadius(20)
                }
                .buttonStyle(ButtonPressAnimationStyle())
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Convenience Initializers

extension EmptyState {
    /// Empty state for no sessions
    static func noSessions(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            icon: TryTennisIcon.mascot.swiftUIImage,
            title: "No Sessions Yet",
            message: "Start analyzing your swing to see your progress here",
            actionTitle: "Start Analyzing",
            action: action
        )
    }

    /// Empty state for no history
    static func noHistory(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            icon: TryTennisIcon.clock.swiftUIImage,
            title: "No History",
            message: "Your completed sessions will appear here",
            actionTitle: "Start First Session",
            action: action
        )
    }

    /// Empty state for general use
    static func custom(
        icon: Image? = nil,
        title: String,
        message: String
    ) -> EmptyState {
        EmptyState(
            icon: icon,
            title: title,
            message: message
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        EmptyState.noSessions {
            print("Start analyzing!")
        }

        EmptyState.noHistory {
            print("Start first session")
        }

        EmptyState.custom(
            icon: TryTennisIcon.magnifyingglass.swiftUIImage,
            title: "No Results Found",
            message: "Try adjusting your search criteria"
        )
    }
    .background(Token.black.swiftUIColor)
}
