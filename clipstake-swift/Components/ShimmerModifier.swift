import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var shimmerPhase: Bool = false

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    ShimmerOverlay(phase: shimmerPhase)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                )
                .opacity(shimmerPhase ? 0.6 : 0.35)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: shimmerPhase
                )
                .onAppear { shimmerPhase = true }
        } else {
            content
        }
    }
}

private struct ShimmerOverlay: View {
    let phase: Bool

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.3),
                Color.white.opacity(0)
            ],
            startPoint: phase ? .leading : .trailing,
            endPoint: phase ? .trailing : .leading
        )
        .animation(
            .linear(duration: 1.2).repeatForever(autoreverses: false),
            value: phase
        )
    }
}

// MARK: - Skeleton Card Shape

struct SkeletonRect: View {
    var cornerRadius: CGFloat = Radius.md
    var height: CGFloat = 16

    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(height: height)
            .opacity(shimmer ? 0.6 : 0.3)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}
