import SwiftUI

// MARK: - Root View (auth router)

struct RootView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.appColors) private var colors

    var body: some View {
        Group {
            if sessionManager.isLoading {
                SplashView()
            } else if !sessionManager.isAuthenticated {
                LoginView()
            } else if sessionManager.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            await sessionManager.checkSession()
        }
    }
}

// MARK: - Splash / Launch Screen

private struct SplashView: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            colors.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .foregroundColor(colors.text)
            }
        }
    }
}
