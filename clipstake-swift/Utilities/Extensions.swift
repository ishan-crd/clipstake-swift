import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - View Modifiers

extension View {
    func shimmer(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    func pressable() -> some View {
        buttonStyle(PressableButtonStyle())
    }

    func appBackground(_ colors: AppColors) -> some View {
        background(colors.bg)
    }

    func cardStyle(_ colors: AppColors) -> some View {
        background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

// MARK: - String

extension String {
    var isValidURL: Bool { URL(string: self) != nil && hasPrefix("http") }

    func detectPlatform() -> String? {
        let lowered = lowercased()
        if lowered.contains("tiktok.com")    { return "tiktok" }
        if lowered.contains("instagram.com") { return "instagram" }
        if lowered.contains("youtube.com") || lowered.contains("youtu.be") { return "youtube" }
        if lowered.contains("twitter.com") || lowered.contains("x.com")   { return "twitter" }
        return nil
    }
}

// MARK: - Color for Status

extension AppColors {
    func statusBackground(for status: StatusColor) -> Color {
        switch status {
        case .amber: Color(hex: "#fef3c7")
        case .green: Color(hex: "#dcfce7")
        case .red:   Color(hex: "#fee2e2")
        case .mint:  bgProgress
        case .gray:  bgSecondary
        }
    }

    func statusForeground(for status: StatusColor) -> Color {
        switch status {
        case .amber: Color(hex: "#92400e")
        case .green: success
        case .red:   error
        case .mint:  textProgress
        case .gray:  textTertiary
        }
    }
}

// MARK: - Int cents → display

extension Int {
    var formattedDollars: String {
        let value = Double(self) / 100.0
        return String(format: "$%.2f", value)
    }
}

#if os(iOS)
// MARK: - UIApplication

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
