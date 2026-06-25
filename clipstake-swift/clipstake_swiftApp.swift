import SwiftUI

@main
struct ClipStakeApp: App {
    @State private var themeManager = ThemeManager()
    @State private var sessionManager = SessionManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(ThemeSystemBridge())   // inner: can see environments injected below
                .environment(themeManager)
                .environment(sessionManager)
                .environment(\.appColors, themeManager.colors)
                .preferredColorScheme(
                    themeManager.mode == .light ? .light :
                    themeManager.mode == .dark  ? .dark  : nil
                )
        }
    }
}
