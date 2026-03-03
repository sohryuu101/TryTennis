import SwiftUI

/// Fade-in animation modifier for smooth view appearances
/// Provides multiple fade styles: fade in, fade in up, fade in down
struct FadeInAnimation: ViewModifier {
    var delay: Double = 0
    var duration: Double = 0.4
    var style: FadeStyle = .fadeIn

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(offset)
            .animation(
                .easeOut(duration: duration).delay(delay),
                value: isVisible
            )
    }

    private var isVisible: Bool {
        true // Immediately visible for animation
    }

    private var offset: CGFloat {
        switch style {
        case .fadeIn:
            return 0
        case .fadeInUp:
            return 30
        case .fadeInDown:
            return -30
        }
    }
}

enum FadeStyle {
    case fadeIn
    case fadeInUp
    case fadeInDown
}

// MARK: - View Modifier Extension

extension View {
    /// Applies fade-in animation to the view
    func fadeIn(
        delay: Double = 0,
        duration: Double = 0.4,
        style: FadeStyle = .fadeIn
    ) -> some View {
        self.modifier(FadeInAnimation(delay: delay, duration: duration, style: style))
    }

    /// Fade in with stagger effect for lists
    func fadeInList(
        delay: Double = 0,
        duration: Double = 0.3,
        style: FadeStyle = .fadeIn
    ) -> some View {
        self.modifier(FadeInAnimation(delay: delay, duration: duration, style: style))
    }
}

// MARK: - Staggered Fade In for Lists

struct FadeInModifier: ViewModifier {
    let index: Int
    var baseDelay: Double = 0
    var delayIncrement: Double = 0.1

    func body(content: Content) -> some View {
        content
            .opacity(0)
            .offset(y: 20)
            .animation(
                .easeOut(duration: 0.5)
                .delay(baseDelay + (Double(index) * delayIncrement)),
                value: true
            )
    }
}

extension View {
    /// Applies staggered fade-in animation for list items
    /// - Parameters:
    ///   - index: The index of this item in the list
    ///   - baseDelay: Initial delay before first item appears
    ///   - delayIncrement: Delay between each subsequent item
    func staggeredFadeIn(
        index: Int,
        baseDelay: Double = 0,
        delayIncrement: Double = 0.1
    ) -> some View {
        self.modifier(FadeInModifier(index: index, baseDelay: baseDelay, delayIncrement: delayIncrement))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Fade in styles
        HStack(spacing: 20) {
            Text("Fade In")
                .fadeIn(style: .fadeIn)
                .foregroundColor(Token.white.swiftUIColor)

            Text("Up")
                .fadeIn(style: .fadeInUp)
                .foregroundColor(Token.white.swiftUIColor)

            Text("Down")
                .fadeIn(style: .fadeInDown)
                .foregroundColor(Token.white.swiftUIColor)
        }

        // Staggered list
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    Circle()
                        .fill(Token.accent500.swiftUIColor)
                        .frame(width: 12, height: 12)
                    Text("Item \(index + 1)")
                        .font(.body)
                        .foregroundColor(Token.white.swiftUIColor)
                    Spacer()
                }
                .staggeredFadeIn(index: index)
            }
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
