import SwiftUI

/// Custom loading indicator with smooth animations
/// Supports multiple styles: spinner, dots, pulse
struct LoadingIndicator: View {
    var style: LoadingStyle = .spinner
    var size: CGFloat = 40
    var color: Color = Token.accent500.swiftUIColor

    var body: some View {
        Group {
            switch style {
            case .spinner:
                spinnerView
            case .dots:
                dotsView
            case .pulse:
                pulseView
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Spinner

    private var spinnerView: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3))

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isSpinning
                )
        }
    }

    // MARK: - Dots

    private var dotsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isScaling ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isScaling
                    )
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Pulse

    private var pulseView: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size, height: size)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .animation(
                    .easeOut(duration: 1.2)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )

            Circle()
                .fill(color)
                .frame(width: size * 0.4, height: size * 0.4)
        }
    }

    // MARK: - Animation States

    @State private var isSpinning = true
    @State private var isScaling = true
    @State private var isPulsing = true

    private var dotSize: CGFloat {
        switch size {
        case _ where size < 30: return 6
        case _ where size < 50: return 8
        default: return 10
        }
    }
}

// MARK: - Loading Styles

enum LoadingStyle {
    case spinner
    case dots
    case pulse
}

// MARK: - View Modifiers

extension LoadingIndicator {
    /// Changes the loading style
    func style(_ style: LoadingStyle) -> LoadingIndicator {
        var view = self
        view.style = style
        return view
    }

    /// Customizes the size
    func customSize(_ size: CGFloat) -> LoadingIndicator {
        var view = self
        view.size = size
        return view
    }

    /// Customizes the color
    func customColor(_ color: Color) -> LoadingIndicator {
        var view = self
        view.color = color
        return view
    }
}

// MARK: - Convenience Initializers

extension LoadingIndicator {
    /// Small loading indicator
    static func small(style: LoadingStyle = .spinner) -> LoadingIndicator {
        LoadingIndicator(style: style, size: 24)
    }

    /// Large loading indicator
    static func large(style: LoadingStyle = .spinner) -> LoadingIndicator {
        LoadingIndicator(style: style, size: 60)
    }
}

// MARK: - Full Screen Loading Overlay

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isLoading {
                ZStack {
                    Rectangle()
                        .fill(.black.opacity(0.6))

                    VStack(spacing: 16) {
                        LoadingIndicator.large(style: .pulse)

                        if let message = message {
                            Text(message)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Token.white.swiftUIColor)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// Shows a loading overlay over the view
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        self.modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Spinner
        VStack(spacing: 12) {
            LoadingIndicator(style: .spinner)
            Text("Spinner")
                .foregroundColor(Token.gray400.swiftUIColor)
        }

        // Dots
        VStack(spacing: 12) {
            LoadingIndicator(style: .dots)
            Text("Dots")
                .foregroundColor(Token.gray400.swiftUIColor)
        }

        // Pulse
        VStack(spacing: 12) {
            LoadingIndicator(style: .pulse)
            Text("Pulse")
                .foregroundColor(Token.gray400.swiftUIColor)
        }

        // Custom sizes
        HStack(spacing: 20) {
            LoadingIndicator.small(style: .spinner)
            LoadingIndicator(style: .dots)
            LoadingIndicator.large(style: .pulse)
        }

        // With overlay
        ZStack {
            Rectangle()
                .fill(Token.gray50.swiftUIColor)
                .frame(width: 200, height: 200)

            Text("Content behind")
                .foregroundColor(Token.gray500.swiftUIColor)
        }
        .frame(width: 200, height: 200)
        .loadingOverlay(isLoading: true, message: "Loading...")
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
