import SwiftUI

/// Slide-up animation modifier for sheet-like presentations
/// Similar to iOS sheet animations but customizable
struct SlideUpAnimation: ViewModifier {
    var delay: Double = 0
    var duration: Double = 0.5
    var offset: CGFloat = 100

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : offset)
            .opacity(isVisible ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8).delay(delay),
                value: isVisible
            )
    }

    private var isVisible: Bool {
        true
    }
}

// MARK: - View Modifier Extension

extension View {
    /// Applies slide-up animation from bottom
    func slideUp(
        delay: Double = 0,
        duration: Double = 0.5,
        offset: CGFloat = 100
    ) -> some View {
        self.modifier(SlideUpAnimation(delay: delay, duration: duration, offset: offset))
    }

    /// Slide-up animation specifically for sheets
    func sheetPresentation(isPresented: Bool) -> some View {
        self.offset(y: isPresented ? 0 : UIScreen.main.bounds.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isPresented)
    }
}

// MARK: - Slide Down Animation

struct SlideDownAnimation: ViewModifier {
    var delay: Double = 0
    var duration: Double = 0.4

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : -100)
            .opacity(isVisible ? 1 : 0)
            .animation(
                .easeIn(duration: duration).delay(delay),
                value: isVisible
            )
    }

    private var isVisible: Bool {
        true
    }
}

extension View {
    /// Applies slide-down animation from top
    func slideDown(
        delay: Double = 0,
        duration: Double = 0.4
    ) -> some View {
        self.modifier(SlideDownAnimation(delay: delay, duration: duration))
    }
}

// MARK: - Slide In From Sides

struct SlideInAnimation: ViewModifier {
    var delay: Double = 0
    var duration: Double = 0.4
    var fromLeading: Bool = true

    func body(content: Content) -> some View {
        content
            .offset(x: isVisible ? 0 : (fromLeading ? -300 : 300))
            .opacity(isVisible ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.75).delay(delay),
                value: isVisible
            )
    }

    private var isVisible: Bool {
        true
    }
}

extension View {
    /// Slide in from leading edge
    func slideInFromLeading(
        delay: Double = 0,
        duration: Double = 0.4
    ) -> some View {
        self.modifier(SlideInAnimation(delay: delay, duration: duration, fromLeading: true))
    }

    /// Slide in from trailing edge
    func slideInFromTrailing(
        delay: Double = 0,
        duration: Double = 0.4
    ) -> some View {
        self.modifier(SlideInAnimation(delay: delay, duration: duration, fromLeading: false))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Slide up
        VStack(spacing: 12) {
            Text("Slide Up Example")
                .foregroundColor(Token.white.swiftUIColor)

            Card(style: .glass) {
                VStack(spacing: 8) {
                    Text("Content")
                        .foregroundColor(Token.white.swiftUIColor)
                    Text("Slides up from bottom")
                        .foregroundColor(Token.gray400.swiftUIFont)
                }
            }
            .frame(width: 200, height: 120)
        }
        .slideUp()

        // Slide down
        Text("Slide Down Example")
            .foregroundColor(Token.white.swiftUIColor)
            .slideDown()

        // Slide from sides
        HStack(spacing: 20) {
            VStack {
                Text("From Leading")
                    .foregroundColor(Token.white.swiftUIFont)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Token.accent500.swiftUIColor)
                    .frame(width: 100, height: 60)
                    .slideInFromLeading()
            }

            VStack {
                Text("From Trailing")
                    .foregroundColor(Token.white.swiftUIColor)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Token.primary500.swiftUIColor)
                    .frame(width: 100, height: 60)
                    .slideInFromTrailing()
            }
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
