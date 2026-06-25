import SwiftUI

struct SettingsView: View {
    @Environment(\.appColors) private var colors
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss

    @Binding var showPersonalInfo: Bool
    @Binding var showConnectedAccounts: Bool
    @Binding var showAppearance: Bool
    @Binding var showBugReport: Bool

    @State private var notificationsEnabled = true
    @State private var showSignOutAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.bg, colors.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colors.text)
                        }
                        Text("Settings")
                            .font(AppFont.Display.bold(20))
                            .foregroundColor(colors.text)
                            .frame(maxWidth: .infinity)
                        Spacer().frame(width: 32)
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 16)

                    // Account section
                    settingsSection(title: "Account") {
                        settingsRow(icon: "person", label: "Personal information") {
                            showPersonalInfo = true
                        }
                        Divider().padding(.leading, 56)
                        settingsRow(icon: "person.2", label: "Connected accounts") {
                            showConnectedAccounts = true
                        }
                    }

                    // Preferences section
                    settingsSection(title: "Preferences") {
                        settingsRow(icon: "paintpalette", label: "Appearance") {
                            showAppearance = true
                        }
                        Divider().padding(.leading, 56)
                        HStack(spacing: 12) {
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                                .foregroundColor(colors.iconSecondary)
                                .frame(width: 36, height: 36)
                                .background(colors.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                            Text("Notifications")
                                .font(AppFont.Body.medium(15))
                                .foregroundColor(colors.text)

                            Spacer()

                            Toggle("", isOn: $notificationsEnabled)
                                .tint(colors.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Support section
                    settingsSection(title: "Support") {
                        settingsRow(icon: "ant", label: "Report a bug") {
                            showBugReport = true
                        }
                    }

                    // Danger zone
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign out")
                            .font(AppFont.Body.medium(16))
                            .foregroundColor(colors.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(colors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, Layout.pagePadX)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Sign out?", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                Task { await sessionManager.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(AppFont.Body.regular(11))
                .foregroundColor(colors.textTertiary)
                .tracking(0.5)
                .padding(.horizontal, Layout.pagePadX + 4)

            VStack(spacing: 0) {
                content()
            }
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .padding(.horizontal, Layout.pagePadX)
        }
    }

    private func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(colors.iconSecondary)
                    .frame(width: 36, height: 36)
                    .background(colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                Text(label)
                    .font(AppFont.Body.medium(15))
                    .foregroundColor(colors.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
