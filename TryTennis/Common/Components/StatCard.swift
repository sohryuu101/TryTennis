import SwiftUI

/// Card component for displaying statistics with icon and value
/// Great for showing shot counts, success rates, etc.
struct StatCard: View {
    let icon: Image
    let title: String
    let value: String
    var subtitle: String? = nil
    var color: Color = Token.primary500.swiftUIColor

    // Layout options
    var size: StatCardSize = .medium
    var style: StatCardStyle = .glass

    init(
        icon: Image,
        title: String,
        value: String,
        subtitle: String? = nil,
        color: Color = Token.primary500.swiftUIColor,
        size: StatCardSize = .medium,
        style: StatCardStyle = .glass
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.size = size
        self.style = style
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            icon
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
                .frame(width: iconFrameSize, height: iconFrameSize)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                // Value
                Text(value)
                    .font(.system(size: valueFontSize, weight: .bold))
                    .foregroundColor(.white)

                // Title
                Text(title)
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(Token.gray300.swiftUIColor)

                // Subtitle (optional)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Token.gray400.swiftUIColor)
                }
            }

            Spacer()
        }
        .padding(padding)
        .background(backgroundView)
        .cornerRadius(cornerRadius)
    }

    private var backgroundView: some View {
        Group {
            if style == .glass {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.thinMaterial)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Token.gray50.swiftUIColor)
            }
        }
    }

    // MARK: - Sizing

    private var iconSize: CGFloat {
        switch size {
        case .small: return 18
        case .medium: return 22
        case .large: return 28
        }
    }

    private var iconFrameSize: CGFloat {
        switch size {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }

    private var valueFontSize: CGFloat {
        switch size {
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        }
    }

    private var titleFontSize: CGFloat {
        switch size {
        case .small: return 11
        case .medium: return 13
        case .large: return 15
        }
    }

    private var padding: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
}

// MARK: - Size & Style Enums

enum StatCardSize {
    case small
    case medium
    case large
}

enum StatCardStyle {
    case glass
    case solid
}

// MARK: - Convenience Initializers

extension StatCard {
    /// Creates a stat card for successful shots
    static func success(value: Int, size: StatCardSize = .medium) -> StatCard {
        StatCard(
            icon: TryTennisIcon.checkmarkCircleFill.swiftUIImage,
            title: "Successful",
            value: "\(value)",
            color: Token.success500.swiftUIColor,
            size: size
        )
    }

    /// Creates a stat card for failed shots
    static func failed(value: Int, size: StatCardSize = .medium) -> StatCard {
        StatCard(
            icon: TryTennisIcon.xmarkCircleFill.swiftUIImage,
            title: "Failed",
            value: "\(value)",
            color: Token.error500.swiftUIColor,
            size: size
        )
    }

    /// Creates a stat card for total attempts
    static func total(value: Int, size: StatCardSize = .medium) -> StatCard {
        StatCard(
            icon: TryTennisIcon.circleFill.swiftUIImage,
            title: "Total",
            value: "\(value)",
            color: Token.accent500.swiftUIColor,
            size: size
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            StatCard.success(value: 24)
            StatCard.failed(value: 8)
        }

        StatCard.total(value: 32, size: .large)

        StatCard(
            icon: TryTennisIcon.flameFill.swiftUIImage,
            title: "Streak",
            value: "7",
            subtitle: "Personal best!",
            color: Token.accent500.swiftUIColor,
            size: .small
        )

        HStack(spacing: 12) {
            StatCard.success(value: 12, size: .small)
            StatCard.failed(value: 3, size: .small)
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
