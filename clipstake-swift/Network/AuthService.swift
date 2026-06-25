import Foundation
import AuthenticationServices

// MARK: - Auth Service

@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()
    private let baseURL = "https://prod.clipstake.com"

    // MARK: - Social OAuth

    func signInWithSocial(provider: String, contextProvider: ASWebAuthenticationPresentationContextProviding) async throws -> AppUser {
        // Step 1: Get the OAuth redirect URL from Better Auth
        let url = URL(string: "\(baseURL)/api/auth/sign-in/social")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.httpBody = try JSONEncoder().encode(["provider": provider, "callbackURL": "clipstake://auth/callback"])

        let (data, _) = try await URLSession.shared.data(for: req)
        let authResponse = try JSONDecoder().decode(SocialAuthResponse.self, from: data)
        guard let redirectURLString = authResponse.url,
              let redirectURL = URL(string: redirectURLString) else {
            throw AppError.unknown(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No redirect URL"]))
        }

        // Step 2: Present ASWebAuthenticationSession
        let _: URL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: redirectURL,
                callbackURLScheme: "clipstake"
            ) { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: AppError.unknown(NSError(domain: "ASWebAuth", code: -1))) }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = contextProvider
            session.start()
        }

        // Step 3: Exchange callback for session
        return try await fetchAndStoreCookie()
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AppUser {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AppError.unknown(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No identity token"]))
        }

        let url = URL(string: "\(baseURL)/api/auth/sign-in/social")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.httpBody = try JSONEncoder().encode([
            "provider": "apple",
            "idToken": identityToken,
            "callbackURL": "clipstake://auth/callback"
        ])

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            storeCookies(from: http)
        }
        return try await fetchCurrentSession()
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async throws {
        let url = URL(string: "\(baseURL)/api/auth/email-otp/send-verification-otp")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.httpBody = try JSONEncoder().encode(["email": email, "type": "sign-in"])
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let serverMsg = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
            throw AppError.unknown(NSError(domain: "AuthService", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: serverMsg ?? "Failed to send code. Please try again."]))
        }
    }

    func verifyOTP(email: String, otp: String) async throws -> AppUser {
        let url = URL(string: "\(baseURL)/api/auth/sign-in/email-otp")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.httpBody = try JSONEncoder().encode(["email": email, "otp": otp])

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            storeCookies(from: http)
            if !(200..<300).contains(http.statusCode) {
                let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
                if http.statusCode == 429 || msg?.lowercased().contains("too many") == true {
                    throw AppError.unknown(NSError(domain: "AuthService", code: 429,
                        userInfo: [NSLocalizedDescriptionKey: "Too many attempts. Please wait a moment and try again."]))
                }
                if http.statusCode == 403 {
                    throw AppError.unknown(NSError(domain: "AuthService", code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "This account is not active. Contact support."]))
                }
                throw AppError.unknown(NSError(domain: "AuthService", code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "The code you've entered is incorrect. Please try again."]))
            }
        }
        return try await fetchCurrentSession()
    }

    // MARK: - Session

    func fetchAndStoreCookie() async throws -> AppUser {
        let user = try await fetchCurrentSession()
        return user
    }

    func fetchCurrentSession() async throws -> AppUser {
        let url = URL(string: "\(baseURL)/api/auth/get-session")!
        var req = URLRequest(url: url)
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        if let cookie = KeychainHelper.get(KeychainHelper.sessionCookieKey) {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            storeCookies(from: http)
        }

        let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
        guard let user = sessionResponse.user else {
            throw AppError.unauthorized
        }
        return user
    }

    func signOut() async throws {
        let url = URL(string: "\(baseURL)/api/auth/sign-out")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        if let cookie = KeychainHelper.get(KeychainHelper.sessionCookieKey) {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        _ = try? await URLSession.shared.data(for: req)
        KeychainHelper.delete(KeychainHelper.sessionCookieKey)
    }

    // MARK: - Cookie Storage

    private func storeCookies(from response: HTTPURLResponse) {
        guard let setCookie = response.value(forHTTPHeaderField: "Set-Cookie") else { return }
        KeychainHelper.set(setCookie, forKey: KeychainHelper.sessionCookieKey)
    }
}

// MARK: - Response Models

private struct SocialAuthResponse: Codable {
    let url: String?
}

private struct SessionResponse: Codable {
    let session: SessionData?
    let user: AppUser?
}

private struct SessionData: Codable {
    let id: String
    let userId: String
}
