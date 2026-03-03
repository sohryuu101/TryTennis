import SwiftUI

/// Modern card component with glassmorphism effect
/// Supports multiple styles: glass, solid, gradient
struct Card<Content: View>: View {
    let content: Content

    // Style properties
    var style: CardStyle = .glass
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 8
    var padding: CGFloat = 16

    init(style: CardStyle = .glass, cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .glass:
            glassBackground
        case .solid:
            solidBackground
        case .gradient(let colors):
            gradientBackground(colors)
        }
    }

    private var glassBackground: some View {
        ZStack {
            // Blur effect
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Token.white.swiftUIColor.opacity(0.2), lineWidth: 1)
        }
    }

    private var solidBackground: some View {
        Token.gray50.swiftUIColor
    }

    private func gradientBackground(_ colors: [Color]) -> some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        Color.black.opacity(0.1)
    }
}

// MARK: - Card Styles

enum CardStyle {
    case glass
    case solid
    case gradient(colors: [Color])
}

// MARK: - Stroke Border Extension

extension View {
    func strokeBorder(_ color: Color, lineWidth: CGFloat) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: lineWidth)
        )
    }
}

// MARK: - Convenience Initializers

extension Card where Content == EmptyView {
    /// Creates an empty card with just background styling
    static func placeholder(style: CardStyle = .glass, cornerRadius: CGFloat = 16) -> some View {
        Card(style: style, cornerRadius: cornerRadius) {
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Glass card
        Card(style: .glass) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Card")
                    .font(.headline)
                    .foregroundColor(Token.white.swiftUIColor)
                Text("Modern glassmorphism effect with blur and subtle border")
                    .font(.caption)
                    .foregroundColor(Token.gray300.swiftUIColor)
            }
        }

        // Solid card
        Card(style: .solid) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Solid Card")
                    .font(.headline)
                    .foregroundColor(Token.black.swiftUIColor)
                Text("Simple solid background")
                    .font(.caption)
                    .foregroundColor(Token.gray500.swiftUIColor)
            }
        }

        // Gradient card
        Card(style: .gradient(colors: [Token.primary500.swiftUIColor, Token.primary300.swiftUIColor])) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gradient Card")
                    .font(.headline)
                    .foregroundColor(Token.white.swiftUIColor)
                Text("Beautiful gradient background")
                    .font(.caption)
                    .foregroundColor(Token.white.opacity(0.8))
            }
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
