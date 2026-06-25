import SwiftUI
import Observation

enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: "Auto"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }
}

@Observable
final class ThemeManager {
    var mode: ThemeMode = .light

    var isDark: Bool {
        switch mode {
        case .system: _systemDark
        case .light:  false
        case .dark:   true
        }
    }

    var colors: AppColors { isDark ? .dark : .light }

    private var _systemDark: Bool = false

    init() {
        if let stored = UserDefaults.standard.string(forKey: "app_theme_mode"),
           let m = ThemeMode(rawValue: stored) {
            mode = m
        }
    }

    func setMode(_ newMode: ThemeMode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: "app_theme_mode")
    }

    func updateSystemScheme(_ isDark: Bool) {
        _systemDark = isDark
    }
}


// MARK: - System Color Scheme Bridge

struct ThemeSystemBridge: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .onChange(of: colorScheme, initial: true) { _, scheme in
                themeManager.updateSystemScheme(scheme == .dark)
            }
    }
}
