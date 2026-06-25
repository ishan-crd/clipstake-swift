import SwiftUI

// MARK: - Profile View Model

@Observable
@MainActor final class ProfileViewModel {
    var user: AppUser?
    var balance: BalanceBreakdown?
    var isLoading = false
    var isRefreshing = false

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUser() }
            group.addTask { await self.fetchBalance() }
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUser() }
            group.addTask { await self.fetchBalance() }
        }
    }

    private func fetchUser() async {
        do {
            let u: AppUser = try await TRPCClient.shared.query("user.getProfile")
            user = u
        } catch {}
    }

    private func fetchBalance() async {
        do {
            let b: BalanceBreakdown = try await TRPCClient.shared.query("campaign.getUserBalance")
            balance = b
        } catch {}
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @Environment(\.appColors) private var colors
    @Environment(SessionManager.self) private var sessionManager

    @State private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert = false
    @State private var showHelp = false
    @State private var showBugReport = false
    @State private var showAppearance = false
    @State private var showPersonalInfo = false
    @State private var showConnectedAccounts = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                LinearGradient(
                    colors: [colors.bg, colors.bgSecondary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Avatar + name
                        avatarSection
                            .padding(.top, 32)
                            .padding(.bottom, 20)

                        // Balance card
                        if let balance = viewModel.balance {
                            profileBalanceCard(balance)
                                .padding(.horizontal, Layout.pagePadX)
                                .padding(.bottom, 20)
                        } else if viewModel.isLoading {
                            SkeletonRect(height: 90)
                                .padding(.horizontal, Layout.pagePadX)
                                .padding(.bottom, 20)
                        }

                        // Menu
                        menuList
                            .padding(.horizontal, Layout.pagePadX)

                        Spacer(minLength: 100)
                    }
                }
                .refreshable { await viewModel.refresh() }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { route in
                switch route {
                case "referrals": ReferralsView()
                case "settings":  SettingsView(showPersonalInfo: $showPersonalInfo, showConnectedAccounts: $showConnectedAccounts, showAppearance: $showAppearance, showBugReport: $showBugReport)
                default: EmptyView()
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpSupportSheet()
            }
            .sheet(isPresented: $showBugReport) {
                BugReportSheet()
            }
            .sheet(isPresented: $showAppearance) {
                AppearanceSheet()
            }
            .sheet(isPresented: $showPersonalInfo) {
                if let user = viewModel.user {
                    PersonalInfoSheet(user: user) { updated in
                        viewModel.user = updated
                    }
                }
            }
            .sheet(isPresented: $showConnectedAccounts) {
                ConnectedAccountsSheet()
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await sessionManager.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again.")
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            // Avatar
            Group {
                if let urlStr = viewModel.user?.image, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Image("pfp").resizable().scaledToFill()
                        }
                    }
                } else {
                    Image("pfp").resizable().scaledToFill()
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(colors.border, lineWidth: 1.5))

            VStack(spacing: 4) {
                if viewModel.isLoading && viewModel.user == nil {
                    SkeletonRect(height: 20).frame(width: 140)
                    SkeletonRect(height: 14).frame(width: 100)
                } else {
                    Text(viewModel.user?.name ?? "")
                        .font(AppFont.Display.semibold(20))
                        .foregroundColor(colors.text)
                    if let username = viewModel.user?.username {
                        Text("@\(username)")
                            .font(AppFont.Body.regular(14))
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Balance Card

    private func profileBalanceCard(_ balance: BalanceBreakdown) -> some View {
        ZStack {
            LinearGradient(
                colors: [colors.accent, colors.accentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Balance")
                        .font(AppFont.Body.regular(12))
                        .foregroundColor(AppColors.onBrandWhite.opacity(0.8))
                    Text(balance.formattedTotal)
                        .font(AppFont.Display.bold(28))
                        .foregroundColor(AppColors.onBrandWhite)
                }
                Spacer()
                Button {
                    // Navigate to wallet tab handled at MainTabView level
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(AppColors.onBrandWhite.opacity(0.7))
                }
            }
            .padding(16)
        )
        .frame(height: 90)
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(spacing: 8) {
            // Referrals
            menuItem(icon: "link", label: "Referrals") {
                navigationPath.append("referrals")
            }

            // Settings
            menuItem(icon: "person", label: "Personal information") {
                showPersonalInfo = true
            }

            menuItem(icon: "person.2", label: "Connected accounts") {
                showConnectedAccounts = true
            }

            menuItem(icon: "paintpalette", label: "Appearance") {
                showAppearance = true
            }

            menuItem(icon: "questionmark.circle", label: "Help & support") {
                showHelp = true
            }

            menuItem(icon: "ant", label: "Report a bug") {
                showBugReport = true
            }

            Divider().padding(.vertical, 4)

            // Sign out (red)
            Button {
                showSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18))
                        .foregroundColor(colors.error)
                        .frame(width: 36, height: 36)
                        .background(colors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                    Text("Sign out")
                        .font(AppFont.Body.medium(15))
                        .foregroundColor(colors.error)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(colors.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func menuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
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
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
