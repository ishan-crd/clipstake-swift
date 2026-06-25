import SwiftUI
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

// MARK: - Login View

private struct Slide {
    let imageName: String
    let heading: String
    let subheading: String
    let imageSize: CGFloat
    let imageOffsetTop: CGFloat
}

private let slides: [Slide] = [
    Slide(
        imageName: "login1",
        heading: "Get paid for content you're already making",
        subheading: "Browse brand campaigns and earn per 1,000 views, no pitching, no negotiations.",
        imageSize: 420, imageOffsetTop: 0
    ),
    Slide(
        imageName: "login2",
        heading: "Pick a campaign. Post your clip. That's it.",
        subheading: "Pick a campaign, follow the brief, submit your clip. Get approved, get paid.",
        imageSize: 420, imageOffsetTop: 0
    ),
    Slide(
        imageName: "login3",
        heading: "Track views, watch your balance grow",
        subheading: "Track views and earnings per submission. Claim your balance anytime.",
        imageSize: 480, imageOffsetTop: 10
    ),
]

struct LoginView: View {
    private let colors = AppColors.light

    @Environment(SessionManager.self) private var sessionManager

    @State private var activeSlide = 0
    @State private var slideOpacity: Double = 1
    @State private var slideOffset: CGFloat = 0

    @State private var email = ""
    @State private var emailError = false
    @State private var isLoading = false
    @State private var error: String?

    @State private var showOTP = false

    private let slideInterval: TimeInterval = 4

    var body: some View {
        if showOTP {
            OTPView(
                colors: colors,
                email: email,
                sessionManager: sessionManager,
                onBack: { showOTP = false }
            )
        } else {
            mainScreen
        }
    }

    // MARK: - Main screen

    private var mainScreen: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen background image
                Image("login-bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                           height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .clipped()

                // Floating illustration at top
                let slide = slides[activeSlide]
                VStack(spacing: 0) {
                    Image(slide.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(slide.imageSize, geo.size.width * 1.05),
                               height: min(slide.imageSize, geo.size.width * 1.05))
                        .opacity(slideOpacity)
                        .offset(x: slideOffset, y: slide.imageOffsetTop + 15)
                    Spacer()
                }

                // Bottom card pinned to bottom
                VStack(spacing: 0) {
                    Spacer()
                    bottomCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear { startCarousel() }
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFFFFF"), Color(hex: "#F5F3F0")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                // Heading + subheading (animated)
                VStack(spacing: 12) {
                    Text(slides[activeSlide].heading)
                        .font(AppFont.Display.medium(24))
                        .foregroundColor(Color(hex: "#3D0A14"))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .opacity(slideOpacity)
                        .offset(x: slideOffset)

                    Text(slides[activeSlide].subheading)
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(slideOpacity)
                        .offset(x: slideOffset)
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)

                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == activeSlide ? Color(hex: "#8B1A2A") : Color(hex: "#D4C5BC"))
                            .frame(width: i == activeSlide ? 16 : 4, height: 4)
                            .animation(.spring(response: 0.3), value: activeSlide)
                    }
                }
                .padding(.top, 16)

                // Form
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(AppFont.Body.semibold(14))
                            .foregroundColor(colors.text)

                        TextField("Enter your email", text: $email)
                            .font(AppFont.Body.regular(14))
                            .foregroundColor(colors.text)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(colors.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .stroke(emailError ? colors.error : colors.border, lineWidth: 1)
                            )
                            .onChange(of: email) { _, _ in emailError = false }

                        if emailError {
                            Text("The email you've entered is invalid.")
                                .font(AppFont.Body.regular(13))
                                .foregroundColor(colors.error)
                        }
                        if let err = error {
                            Text(err)
                                .font(AppFont.Body.regular(13))
                                .foregroundColor(colors.error)
                        }
                    }

                    // Submit button
                    Button(action: { Task { await sendOTP() } }) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Submit")
                                    .font(AppFont.Body.semibold(14))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(email.isEmpty ? Color(hex: "#8B1A2A").opacity(0.6) : Color(hex: "#8B1A2A"))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    }
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(PressableButtonStyle())

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(colors.divider).frame(height: 1)
                        Text("Or continue with")
                            .font(AppFont.Body.semibold(12))
                            .foregroundColor(colors.textSecondary)
                        Rectangle().fill(colors.divider).frame(height: 1)
                    }

                    // Social icon circles
                    HStack(spacing: 16) {
                        socialButton("globe", label: "Google") {
                            Task { await signInSocial("google") }
                        }
                        socialButton("gamecontroller.fill", label: "Discord") {
                            Task { await signInSocial("discord") }
                        }
                        socialButton("apple.logo", label: "Apple") {
                            Task { await signInSocial("apple") }
                        }
                    }

                    // Terms
                    Text("By continuing, you accept our Terms & Conditions and Privacy Policy.")
                        .font(AppFont.Body.regular(11))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Social circle button

    private func socialButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(colors.text)
                .frame(width: 52, height: 52)
                .background(Color.white)
                .clipShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Carousel

    private func startCarousel() {
        Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: true) { _ in
            animateToNextSlide()
        }
    }

    private func animateToNextSlide() {
        let next = (activeSlide + 1) % slides.count
        withAnimation(.easeInOut(duration: 0.25)) {
            slideOpacity = 0
            slideOffset = -30
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeSlide = next
            slideOffset = 30
            withAnimation(.easeInOut(duration: 0.25)) {
                slideOpacity = 1
                slideOffset = 0
            }
        }
    }

    // MARK: - Actions

    private func sendOTP() async {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let valid = trimmed.contains("@") && trimmed.contains(".")
        guard valid else { emailError = true; return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await AuthService.shared.sendOTP(email: trimmed)
            showOTP = true
        } catch {
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func signInSocial(_ provider: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        #if os(iOS)
        do {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.keyWindow else { return }
            let contextProvider = WindowContextProvider(window: window)
            let user = try await AuthService.shared.signInWithSocial(provider: provider, contextProvider: contextProvider)
            sessionManager.signIn(user: user)
        } catch {
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
        #endif
    }
}

// MARK: - OTP Screen

private struct OTPView: View {
    let colors: AppColors
    let email: String
    let sessionManager: SessionManager
    let onBack: () -> Void

    @State private var otpValue = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var resendTimer = 60
    @State private var resendTask: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Verify your email")
                    .font(AppFont.Display.medium(28))
                    .foregroundColor(Color(hex: "#3D0A14"))
                    .padding(.top, 60)
                    .padding(.bottom, 12)

                Text("Check \(email) for an email from Clipstake.com and enter your code below.")
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .padding(.bottom, 32)

                Text("Enter code")
                    .font(AppFont.Body.semibold(14))
                    .foregroundColor(colors.text)
                    .padding(.bottom, 12)

                // OTP boxes
                OTPBoxes(value: $otpValue, hasError: error != nil && otpValue.count == 6, colors: colors)
                    .onChange(of: otpValue) { _, v in
                        if v.count == 6 { Task { await verify(code: v) } }
                    }

                if let err = error {
                    Text(err)
                        .font(AppFont.Body.regular(13))
                        .foregroundColor(colors.error)
                        .padding(.top, 8)
                }

                // Resend row
                HStack(spacing: 6) {
                    Text("Didn't get an email?")
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textSecondary)
                    if resendTimer > 0 {
                        Text("\(resendTimer)")
                            .font(AppFont.Body.semibold(14))
                            .foregroundColor(colors.textSecondary)
                    }
                    Button("Resend") { Task { await resend() } }
                        .font(AppFont.Body.semibold(14))
                        .foregroundColor(resendTimer > 0 ? Color(hex: "#D4A0A8") : Color(hex: "#8B1A2A"))
                        .disabled(resendTimer > 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Submit
                Button(action: { Task { await verify(code: otpValue) } }) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit")
                                .font(AppFont.Body.semibold(14))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(otpValue.count < 6 ? Color(hex: "#8B1A2A").opacity(0.6) : Color(hex: "#8B1A2A"))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(isLoading || otpValue.count < 6)
                .buttonStyle(PressableButtonStyle())
                .padding(.bottom, 12)

                // Back
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Go back")
                            .font(AppFont.Body.semibold(14))
                    }
                    .foregroundColor(colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(colors.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 24)
        }
        .background(colors.bg.ignoresSafeArea())
        .onAppear { startResendTimer() }
        .onDisappear { resendTask?.invalidate() }
    }

    private func startResendTimer() {
        resendTimer = 60
        resendTask?.invalidate()
        resendTask = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if resendTimer > 0 { resendTimer -= 1 } else { t.invalidate() }
        }
    }

    private func verify(code: String) async {
        guard code.count == 6 else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let user = try await AuthService.shared.verifyOTP(email: email, otp: code)
            sessionManager.signIn(user: user)
        } catch {
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resend() async {
        guard resendTimer == 0 else { return }
        do {
            try await AuthService.shared.sendOTP(email: email)
            startResendTimer()
        } catch {
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - OTP Boxes

private struct OTPBoxes: View {
    @Binding var value: String
    let hasError: Bool
    let colors: AppColors
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden real input — sits behind boxes, captures all keyboard input
            TextField("", text: $value)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .opacity(0.02)

            // Visual boxes (non-interactive so taps fall through to TextField)
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let digit = i < value.count
                        ? String(value[value.index(value.startIndex, offsetBy: i)])
                        : ""
                    let isCurrent = i == value.count
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(hasError ? colors.bgAccentRed : colors.bgSecondary)
                        if isCurrent && isFocused {
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(colors.border, lineWidth: 1.5)
                        }
                        Text(digit.isEmpty ? "–" : digit)
                            .font(AppFont.Body.semibold(20))
                            .foregroundColor(digit.isEmpty ? colors.border : colors.text)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                }
            }
            .allowsHitTesting(false)
        }
        .onTapGesture { isFocused = true }
        .onChange(of: value) { _, v in
            let filtered = String(v.filter(\.isNumber).prefix(6))
            if filtered != v { value = filtered }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isFocused = true
            }
        }
    }
}

// MARK: - Window Context Provider

#if os(iOS)
final class WindowContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let window: UIWindow
    init(window: UIWindow) { self.window = window }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}
#endif
