import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case marketplace = 0
    case workspace   = 1
    case submissions = 2
    case wallet      = 3
    case profile     = 4

    var label: String {
        switch self {
        case .marketplace: "Marketplace"
        case .workspace:   "Home"
        case .submissions: "Submissions"
        case .wallet:      "Wallet"
        case .profile:     "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .marketplace: "house"
        case .workspace:   "bag"
        case .submissions: "film"
        case .wallet:      "banknote"
        case .profile:     "person.circle"
        }
    }

    var filledImage: String { systemImage + ".fill" }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.appColors) private var colors
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SessionManager.self) private var sessionManager

    @State private var selectedTab: AppTab = .marketplace

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabContentStack(selectedTab: selectedTab)

            // Custom tab bar
            CustomTabBar(
                selectedTab: $selectedTab,
                avatarURL: sessionManager.currentUser?.image.flatMap { URL(string: $0) },
                colors: colors,
                isDark: themeManager.isDark
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Content

private struct TabContentStack: View {
    let selectedTab: AppTab

    var body: some View {
        ZStack {
            NavigationStack { CampaignMarketplaceView() }.tag(AppTab.marketplace).opacity(selectedTab == .marketplace ? 1 : 0)
            NavigationStack { WorkspaceView() }.tag(AppTab.workspace).opacity(selectedTab == .workspace ? 1 : 0)
            NavigationStack { SubmissionsView() }.tag(AppTab.submissions).opacity(selectedTab == .submissions ? 1 : 0)
            NavigationStack { WalletView() }.tag(AppTab.wallet).opacity(selectedTab == .wallet ? 1 : 0)
            NavigationStack { ProfileView() }.tag(AppTab.profile).opacity(selectedTab == .profile ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let avatarURL: URL?
    let colors: AppColors
    let isDark: Bool

    @State private var indicatorOffset: CGFloat = 0
    @State private var tabWidth: CGFloat = 0

    private let squareSize: CGFloat = Layout.tabSquareSize
    private let tabs = AppTab.allCases

    var body: some View {
        ZStack(alignment: .bottom) {
            // Glass background
            TabBarGlassBackground()
                .frame(height: tabBarHeight)

            // Top border
            VStack(spacing: 0) {
                Divider()
                    .background(colors.tabBarBorder)
                Spacer()
            }
            .frame(height: tabBarHeight)

            // Tab bar content
            HStack(alignment: .center, spacing: 0) {
                ForEach(tabs, id: \.rawValue) { tab in
                    Spacer(minLength: 0)
                    tabButton(for: tab)
                        .frame(width: squareSize, height: squareSize)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: Layout.tabBarMaxWidth)
            .padding(.horizontal, Layout.tabBarPadX)
            .padding(.top, space(2))
            .padding(.bottom, safeAreaBottom + space(1))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let tw = (geo.size.width - Layout.tabBarPadX * 2) / CGFloat(tabs.count)
                            tabWidth = tw
                            indicatorOffset = CGFloat(selectedTab.rawValue) * tw + (tw - squareSize) / 2 + Layout.tabBarPadX
                        }
                }
            )
            .overlay(alignment: .topLeading) {
                // Sliding crimson square
                slideIndicator
            }
        }
        .frame(height: tabBarHeight)
        .onChange(of: selectedTab) { _, tab in
            withAnimation(.tabSlide) {
                indicatorOffset = CGFloat(tab.rawValue) * tabWidth + (tabWidth - squareSize) / 2 + Layout.tabBarPadX
            }
        }
    }

    private var tabBarHeight: CGFloat { squareSize + space(2) + safeAreaBottom + space(1) }
    private var safeAreaBottom: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 34
        #else
        return 0
        #endif
    }

    private var slideIndicator: some View {
        ZStack {
            // Crimson gradient
            LinearGradient(
                colors: [Palette.Crimson.c400, Palette.Crimson.c500],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Inner glow
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .blur(radius: 4)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .frame(width: squareSize, height: squareSize)
        .offset(x: indicatorOffset, y: space(2))
        .shadow(color: Palette.Crimson.c500.opacity(0.4), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func tabButton(for tab: AppTab) -> some View {
        let isActive = selectedTab == tab
        let activeColor: Color = isDark ? AppColors.activeTabIconDark : AppColors.activeTabIconLight
        let inactiveColor = colors.textTertiary

        Button {
            withAnimation(.tabSlide) { selectedTab = tab }
        } label: {
            Group {
                if tab == .profile {
                    // Avatar circle for profile tab
                    profileAvatar(isActive: isActive, activeColor: activeColor)
                } else {
                    Image(systemName: isActive ? tab.filledImage : tab.systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isActive ? activeColor : inactiveColor)
                }
            }
            .frame(width: squareSize, height: squareSize)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private func profileAvatar(isActive: Bool, activeColor: Color) -> some View {
        let size: CGFloat = 26
        if let url = avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Image("pfp").resizable().scaledToFill()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(isActive ? activeColor : Color.clear, lineWidth: 1.5)
            )
        } else {
            Image("pfp")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(isActive ? activeColor : Color.clear, lineWidth: 1.5)
                )
        }
    }
}
