import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.appColors) private var colors
    @Environment(SessionManager.self) private var sessionManager

    @State private var step: Int = 0
    @State private var username = ""
    @State private var referralCode = ""
    @State private var usernameError: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let steps = ["Username", "Referral", "Confirm"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.bg, colors.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? colors.accent : colors.borderSecondary)
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.conditional, value: step)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Step content
                Group {
                    switch step {
                    case 0:
                        UsernameStep(
                            colors: colors,
                            username: $username,
                            error: usernameError,
                            onNext: { await validateUsername() }
                        )
                    case 1:
                        ReferralStep(
                            colors: colors,
                            code: $referralCode,
                            onNext: { step = 2 },
                            onSkip: { step = 2 }
                        )
                    case 2:
                        ConfirmStep(
                            colors: colors,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            onConfirm: completeOnboarding
                        )
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.conditional, value: step)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private func validateUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            usernameError = "Username is required."
            return
        }
        guard trimmed.count >= 3 else {
            usernameError = "Username must be at least 3 characters."
            return
        }
        guard trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            usernameError = "Only letters, numbers, and underscores."
            return
        }
        usernameError = nil
        withAnimation(.conditional) { step = 1 }
    }

    private func completeOnboarding() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            struct OnboardingInput: Encodable {
                let username: String
                let referralCode: String?
            }
            let _: EmptyResponse = try await TRPCClient.shared.mutate(
                "onboarding.completeProfile",
                input: OnboardingInput(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    referralCode: referralCode.isEmpty ? nil : referralCode
                )
            )
            let user = try await AuthService.shared.fetchCurrentSession()
            sessionManager.signIn(user: user)
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct EmptyResponse: Decodable {}

// MARK: - Username Step

private struct UsernameStep: View {
    let colors: AppColors
    @Binding var username: String
    let error: String?
    let onNext: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a username")
                    .font(AppFont.Display.bold(28))
                    .foregroundColor(colors.text)
                Text("This is how other creators will find you.")
                    .font(AppFont.Body.regular(15))
                    .foregroundColor(colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("@username", text: $username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .font(AppFont.Body.regular(16))
                    .padding()
                    .background(colors.bgInput)
                    .foregroundColor(colors.text)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(error != nil ? colors.error : colors.border, lineWidth: 1)
                    )

                if let err = error {
                    Text(err)
                        .font(AppFont.Body.regular(13))
                        .foregroundColor(colors.error)
                }
            }

            AsyncButton(action: onNext) {
                Text("Continue")
                    .font(AppFont.Body.semibold(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
        }
    }
}

// MARK: - Referral Step

private struct ReferralStep: View {
    let colors: AppColors
    @Binding var code: String
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Got a referral code?")
                    .font(AppFont.Display.bold(28))
                    .foregroundColor(colors.text)
                Text("Enter it to link your account to a referrer.")
                    .font(AppFont.Body.regular(15))
                    .foregroundColor(colors.textSecondary)
            }

            TextField("Referral code (optional)", text: $code)
                .autocapitalization(.allCharacters)
                .autocorrectionDisabled()
                .font(AppFont.Body.regular(16))
                .padding()
                .background(colors.bgInput)
                .foregroundColor(colors.text)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(colors.border, lineWidth: 1)
                )

            Button(action: onNext) {
                Text("Continue")
                    .font(AppFont.Body.semibold(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: onSkip) {
                Text("Skip")
                    .font(AppFont.Body.medium(15))
                    .foregroundColor(colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Confirm Step

private struct ConfirmStep: View {
    let colors: AppColors
    let isLoading: Bool
    let errorMessage: String?
    let onConfirm: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You're a Creator")
                    .font(AppFont.Display.bold(28))
                    .foregroundColor(colors.text)
                Text("ClipStake mobile is for creators who submit short-form clips and earn based on views.")
                    .font(AppFont.Body.regular(15))
                    .foregroundColor(colors.textSecondary)
            }

            VStack(spacing: 12) {
                FeatureRow(icon: "video.fill", text: "Submit clips to brand campaigns", colors: colors)
                FeatureRow(icon: "eye.fill", text: "Earn per 1,000 views on your content", colors: colors)
                FeatureRow(icon: "banknote.fill", text: "Track earnings & get paid", colors: colors)
            }
            .padding()
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))

            if let msg = errorMessage {
                Text(msg)
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.error)
            }

            AsyncButton(action: onConfirm) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Let's go")
                            .font(AppFont.Body.semibold(16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(isLoading)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    let colors: AppColors

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(colors.accent)
                .frame(width: 28, height: 28)
                .background(colors.bgAccent)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(text)
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.text)
        }
    }
}
