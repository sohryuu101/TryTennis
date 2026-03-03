import SwiftUI

/// Shimmer animation modifier for loading states and skeleton screens
/// Creates a shimmering light effect that moves across the view
struct ShimmerViewModifier: ViewModifier {
    var duration: Double = 1.5
    var direction: ShimmerDirection = .leadingToTrailing
    var isActive: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(
                shimmerOverlay
                    .opacity(isActive ? 1 : 0)
            )
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: false), value: isActive)
            .clipped()
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            let gradient = gradientShape(in: geometry)

            gradient
                .animation(
                    .linear(duration: duration)
                        .repeatForever(autoreverses: false),
                    value: isActive
                )
        }
    }

    private func gradientShape(in geometry: GeometryProxy) -> some View {
        let size = geometry.size
        let gradientWidth = size.width * 0.5

        return LinearGradient(
            colors: [
                .clear,
                Token.white.swiftUIColor.opacity(0.3),
                .clear
            ],
            startPoint: startPoint(in: size),
            endPoint: endPoint(in: size, gradientWidth: gradientWidth)
        )
    }

    private func startPoint(in size: CGSize) -> CGPoint {
        switch direction {
        case .leadingToTrailing:
            return CGPoint(x: -size.width * 0.5, y: 0.5)
        case .trailingToLeading:
            return CGPoint(x: size.width * 1.5, y: 0.5)
        case .topToBottom:
            return CGPoint(x: 0.5, y: -size.height * 0.5)
        case .bottomToTop:
            return CGPoint(x: 0.5, y: size.height * 1.5)
        }
    }

    private func endPoint(in size: CGSize, gradientWidth: CGFloat) -> CGPoint {
        switch direction {
        case .leadingToTrailing:
            return CGPoint(x: size.width + gradientWidth, y: 0.5)
        case .trailingToLeading:
            return CGPoint(x: -gradientWidth, y: 0.5)
        case .topToBottom:
            return CGPoint(x: 0.5, y: size.height + gradientWidth)
        case .bottomToTop:
            return CGPoint(x: 0.5, y: -gradientWidth)
        }
    }
}

enum ShimmerDirection {
    case leadingToTrailing
    case trailingToLeading
    case topToBottom
    case bottomToTop
}

// MARK: - View Modifier Extension

extension View {
    /// Applies shimmer animation to the view
    func shimmer(
        duration: Double = 1.5,
        direction: ShimmerDirection = .leadingToTrailing,
        isActive: Bool = true
    ) -> some View {
        self.modifier(ShimmerViewModifier(duration: duration, direction: direction, isActive: isActive))
    }
}

// MARK: - Skeleton Loading Components

struct SkeletonRow: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Token.gray700.swiftUIColor)
            .frame(height: height)
            .if(let width = width) { view in
                view.frame(width: width)
            }
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var diameter: CGFloat = 60

    var body: some View {
        Circle()
            .fill(Token.gray700.swiftUIColor)
            .frame(width: diameter, height: diameter)
            .shimmer()
    }
}

struct SkeletonRect: View {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Token.gray700.swiftUIColor)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 100
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Token.gray700.swiftUIColor)
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Complex Skeleton Views

struct StatCardSkeleton: View {
    var size: StatCardSize = .medium

    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(diameter: iconSize)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonRow(height: valueHeight, width: valueWidth)
                SkeletonRow(height: titleHeight, width: titleWidth)
            }

            Spacer()
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
        )
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }

    private var valueHeight: CGFloat {
        switch size {
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        }
    }

    private var valueWidth: CGFloat {
        switch size {
        case .small: return 40
        case .medium: return 60
        case .large: return 80
        }
    }

    private var titleHeight: CGFloat {
        switch size {
        case .small: return 11
        case .medium: return 13
        case .large: return 15
        }
    }

    private var titleWidth: CGFloat {
        switch size {
        case .small: return 60
        case .medium: return 80
        case .large: return 100
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

// MARK: - Conditional Shimmer Extension

extension View {
    /// Applies shimmer conditionally
    func skeleton(
        isLoading: Bool,
        duration: Double = 1.5
    ) -> some View {
        self.shimmer(duration: duration, isActive: isLoading)
    }
}

// MARK: - Helper Extension

extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        // Basic shimmer examples
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Shimmer")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            SkeletonRow(height: 16, width: 200)
            SkeletonRow(height: 16, width: 150)
            SkeletonRow(height: 16, width: 180)
        }

        // Skeleton circle
        VStack(alignment: .leading, spacing: 12) {
            Text("Skeleton Circle")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            HStack(spacing: 20) {
                SkeletonCircle(diameter: 40)
                SkeletonCircle(diameter: 60)
                SkeletonCircle(diameter: 80)
            }
        }

        // Skeleton card
        VStack(alignment: .leading, spacing: 12) {
            Text("Skeleton Card")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            SkeletonCard(height: 80)
            SkeletonCard(height: 100)
        }

        // Stat card skeleton
        VStack(alignment: .leading, spacing: 12) {
            Text("Stat Card Skeleton")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            StatCardSkeleton(size: .small)
            StatCardSkeleton(size: .medium)
            StatCardSkeleton(size: .large)
        }

        // Complete card skeleton
        VStack(alignment: .leading, spacing: 12) {
            Text("Complete Card Skeleton")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            Card(style: .glass) {
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRow(height: 20, width: 120)
                    SkeletonRow(height: 14, width: 180)
                    SkeletonRow(height: 14, width: 160)

                    HStack(spacing: 12) {
                        SkeletonCircle(diameter: 50)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonRow(height: 16, width: 100)
                            SkeletonRow(height: 12, width: 80)
                        }
                    }
                }
            }
            .frame(width: 300)
        }

        // Different directions
        VStack(alignment: .leading, spacing: 12) {
            Text("Shimmer Directions")
                .font(.headline)
                .foregroundColor(Token.white.swiftUIColor)

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    SkeletonRect(width: 60, height: 60)
                        .shimmer(direction: .leadingToTrailing)
                    Text("→")
                        .foregroundColor(Token.gray400.swiftUIColor)
                }

                VStack(spacing: 8) {
                    SkeletonRect(width: 60, height: 60)
                        .shimmer(direction: .trailingToLeading)
                    Text("←")
                        .foregroundColor(Token.gray400.swiftUIColor)
                }

                VStack(spacing: 8) {
                    SkeletonRect(width: 60, height: 60)
                        .shimmer(direction: .topToBottom)
                    Text("↓")
                        .foregroundColor(Token.gray400.swiftUIColor)
                }

                VStack(spacing: 8) {
                    SkeletonRect(width: 60, height: 60)
                        .shimmer(direction: .bottomToTop)
                    Text("↑")
                        .foregroundColor(Token.gray400.swiftUIColor)
                }
            }
        }
    }
    .padding()
    .background(Token.black.swiftUIColor)
}
