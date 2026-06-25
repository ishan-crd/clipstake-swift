import SwiftUI

// MARK: - Campaign Marketplace View Model

@Observable
@MainActor final class CampaignMarketplaceViewModel {
    var campaigns: [Campaign] = []
    var isLoading = false
    var isLoadingMore = false
    var isRefreshing = false
    var error: AppError?
    var hasMore = true
    var cursor: String?
    var displayName: String = ""
    var balance: BalanceBreakdown?

    private let pageSize = 5

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        await fetchCampaigns(cursor: nil)
        await fetchBalance()
        await fetchDisplayName()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        cursor = nil
        hasMore = true
        await fetchCampaigns(cursor: nil)
        await fetchBalance()
    }

    func loadMore() async {
        guard hasMore && !isLoadingMore && !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchCampaigns(cursor: cursor)
    }

    private func fetchCampaigns(cursor: String?) async {
        do {
            struct Input: Encodable { let limit: Int; let cursor: String? }
            let result: PaginatedResponse<Campaign> = try await TRPCClient.shared.query(
                "campaign.list",
                input: Input(limit: pageSize, cursor: cursor)
            )
            if cursor == nil {
                campaigns = result.items
            } else {
                campaigns.append(contentsOf: result.items)
            }
            self.cursor = result.nextCursor
            self.hasMore = result.hasMore ?? false
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }

    private func fetchBalance() async {
        do {
            let result: BalanceBreakdown = try await TRPCClient.shared.query("campaign.loadUserBalanceBreakdown")
            balance = result
        } catch {}
    }

    private func fetchDisplayName() async {
        do {
            let user: AppUser = try await TRPCClient.shared.query("user.getProfile")
            displayName = user.name
        } catch {}
    }
}

// MARK: - View

struct CampaignMarketplaceView: View {
    @Environment(\.appColors) private var colors
    @Environment(SessionManager.self) private var sessionManager

    @State private var viewModel = CampaignMarketplaceViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [colors.bg, colors.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    // Header
                    headerSection
                        .padding(.horizontal, Layout.pagePadX)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Balance card
                    if let balance = viewModel.balance {
                        balanceCard(balance)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.bottom, 16)
                    } else if viewModel.isLoading {
                        SkeletonRect(height: 140)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.bottom, 16)
                    }

                    // Campaigns section header
                    HStack {
                        Text("Recommended campaigns")
                            .font(AppFont.Display.semibold(14))
                            .foregroundColor(colors.text)
                        Spacer()
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.bottom, 12)

                    // Campaign list
                    if viewModel.isLoading && viewModel.campaigns.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in CampaignSkeletonCard() }
                        }
                        .padding(.horizontal, Layout.pagePadX)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.campaigns.enumerated()), id: \.element.id) { index, campaign in
                                NavigationLink(value: campaign.id) {
                                    CampaignCard(campaign: campaign, colors: colors)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 20)
                                        .animation(
                                            .cardAppear.delay(Double(min(index, 5)) * 0.04),
                                            value: appeared
                                        )
                                }
                                .buttonStyle(PressableButtonStyle())
                                .onAppear {
                                    if index == viewModel.campaigns.count - 1 {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Layout.pagePadX)
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(colors.textTertiary)
                            .padding(.vertical, 20)
                    }

                    // Tab bar spacer
                    Spacer(minLength: 100)
                }
                .padding(.top, 0)
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: String.self) { campaignId in
                CampaignDetailView(campaignId: campaignId)
            }
        }
        .navigationBarHidden(true)
        .task { await viewModel.load() }
        .onAppear {
            withAnimation(.cardAppear.delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .foregroundColor(colors.text)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Welcome back")
                    .font(AppFont.Body.regular(12))
                    .foregroundColor(colors.textSecondary)
                Text(viewModel.displayName.isEmpty ? "..." : viewModel.displayName)
                    .font(AppFont.Body.semibold(15))
                    .foregroundColor(colors.text)
            }
        }
    }

    // MARK: - Balance Card

    private func balanceCard(_ balance: BalanceBreakdown) -> some View {
        ZStack {
            LinearGradient(
                colors: [colors.accent, colors.accentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avail. Balance")
                            .font(AppFont.Body.medium(13))
                            .foregroundColor(AppColors.onBrandWhite.opacity(0.85))
                        Text(balance.formattedTotal)
                            .font(AppFont.Body.bold(32))
                            .foregroundColor(AppColors.onBrandWhite)
                    }
                    Spacer()
                    NavigationLink(value: "wallet") {
                        HStack(spacing: 6) {
                            Image(systemName: "banknote")
                                .font(.system(size: 14))
                            Text("Details")
                                .font(AppFont.Body.medium(13))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.onBrandWhite)
                        .padding(.horizontal, space(2))
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(AppColors.onBrandWhite.opacity(0.5), lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: 8) {
                    miniCard(title: "Total Earned", value: balance.formattedOwed, valueColor: Palette.Green.g700)
                    miniCard(title: "In Review", value: "$0.00", valueColor: Palette.Amber.a700)
                }
            }
            .padding(20)
        )
        .frame(height: 160)
    }

    private func miniCard(title: String, value: String, valueColor: Color) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.8), Color.white.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppFont.Body.regular(11))
                    .foregroundColor(Palette.Sand.s800)
                Text(value)
                    .font(AppFont.Body.medium(14))
                    .foregroundColor(valueColor)
                Spacer(minLength: 0)
            }
            .padding(12)
        )
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Campaign Card

struct CampaignCard: View {
    let campaign: Campaign
    let colors: AppColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: campaign.thumbnailURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(colors.bgTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.lg,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: Radius.lg
                    )
                )

                // Brand logo
                if let logoURL = campaign.brandLogoURL {
                    AsyncImage(url: logoURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Circle().fill(colors.bgSecondary)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .padding(10)
                }

                // CPM badge
                HStack(spacing: 0) {
                    Spacer()
                    if let cpm = campaign.cpmLabel {
                        Text(cpm)
                            .font(AppFont.Body.semibold(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colors.accent)
                            .clipShape(Capsule())
                            .padding(10)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Card body
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(campaign.title)
                    .font(AppFont.Body.semibold(14))
                    .foregroundColor(colors.text)
                    .lineLimit(2)

                // Platform icons + end date
                HStack(spacing: 8) {
                    PlatformIconRow(platforms: campaign.platforms, size: 14, color: colors.iconSecondary)
                    Spacer()
                    Text(campaign.endsInLabel)
                        .font(AppFont.Body.regular(12))
                        .foregroundColor(colors.textSecondary)
                }

                // Progress bar
                SegmentedProgressBar(percentage: campaign.budgetPercentage, colors: colors)

                // Budget remaining
                HStack {
                    Text(campaign.formattedRemaining)
                        .font(AppFont.Body.medium(12))
                        .foregroundColor(colors.textProgress)
                    Text("remaining")
                        .font(AppFont.Body.regular(12))
                        .foregroundColor(colors.textTertiary)
                    Spacer()
                    Text(campaign.formattedBudget)
                        .font(AppFont.Body.regular(11))
                        .foregroundColor(colors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }
}

// MARK: - Segmented Progress Bar

struct SegmentedProgressBar: View {
    let percentage: Double
    let colors: AppColors
    private let totalSegments = 30

    var body: some View {
        let filled = Int((percentage / 100.0) * Double(totalSegments))
        HStack(spacing: 3) {
            ForEach(0..<totalSegments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < filled ? colors.progressFilled : colors.progressEmpty)
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Skeleton Card

struct CampaignSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonRect(cornerRadius: Radius.lg, height: 160)
            SkeletonRect(height: 16).padding(.horizontal, 12)
            SkeletonRect(height: 12).frame(maxWidth: 120).padding(.horizontal, 12)
            SkeletonRect(height: 8).padding(.horizontal, 12)
        }
        .padding(.bottom, 4)
    }
}
