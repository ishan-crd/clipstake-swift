import Foundation
import Observation

// MARK: - Session Manager

@Observable
@MainActor
final class SessionManager {
    static let shared = SessionManager()

    var currentUser: AppUser?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading: Bool = true
    var needsOnboarding: Bool = false

    private init() {}

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await AuthService.shared.fetchCurrentSession()
            handleUser(user)
        } catch {
            currentUser = nil
        }
    }

    func signIn(user: AppUser) {
        handleUser(user)
    }

    func signOut() async {
        try? await AuthService.shared.signOut()
        clearAll()
    }

    func clearAll() {
        currentUser = nil
        needsOnboarding = false
        KeychainHelper.delete(KeychainHelper.sessionCookieKey)
    }

    private func handleUser(_ user: AppUser) {
        currentUser = user
        needsOnboarding = (user.role == "onboarding" || user.username == nil || user.username?.isEmpty == true)
    }
}

