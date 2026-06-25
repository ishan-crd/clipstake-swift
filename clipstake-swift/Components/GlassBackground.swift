import SwiftUI

// MARK: - Frosted Glass Background (UIVisualEffectView wrapper)

#if os(iOS)
import UIKit

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = UIBlurEffect(style: style)
    }
}
#endif

// MARK: - Sheet Glass Background

struct SheetGlassBackground: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
#if os(iOS)
        BlurView(style: themeManager.isDark ? .systemThickMaterialDark : .systemThickMaterial)
            .ignoresSafeArea()
#else
        Color(themeManager.colors.bgCard)
            .ignoresSafeArea()
#endif
    }
}

// MARK: - Tab Bar Glass Background

struct TabBarGlassBackground: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
#if os(iOS)
        BlurView(style: themeManager.isDark ? .systemMaterialDark : .systemMaterial)
            .ignoresSafeArea()
#else
        Color(themeManager.colors.bgCard)
            .ignoresSafeArea()
#endif
    }
}
