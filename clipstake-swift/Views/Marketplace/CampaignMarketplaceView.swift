import SwiftUI

// MARK: - View Model

@Observable
@MainActor final class CampaignMarketplaceViewModel {
    var campaigns: [Campaign] = []
    var isLoading = false
    var isLoadingMore = false
    var isRefreshing = false
    var error: String?
    var hasMore = true
    var offset = 0
    var balance: BalanceBreakdown = .zero

    private let pageSize = 5

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCampaigns(offset: 0) }
            group.addTask { await self.fetchBalance() }
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        offset = 0
        hasMore = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCampaigns(offset: 0) }
            group.addTask { await self.fetchBalance() }
        }
    }

    func loadMore() async {
        guard hasMore && !isLoadingMore && !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchCampaigns(offset: offset)
    }

    private func fetchCampaigns(offset: Int) async {
        do {
            struct Input: Encodable { let limit: Int; let offset: Int }
            let rows: [Campaign] = try await TRPCClient.shared.query(
                "campaign.listMarketplace",
                input: Input(limit: pageSize, offset: offset)
            )
            if offset == 0 {
                campaigns = rows
            } else {
                let existingIds = Set(campaigns.map(\.id))
                campaigns.append(contentsOf: rows.filter { !existingIds.contains($0.id) })
            }
            self.offset = offset + rows.count
            self.hasMore = rows.count >= pageSize
        } catch {
            if offset == 0 { self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription }
        }
    }

    private func fetchBalance() async {
        do {
            let result: BalanceBreakdown = try await TRPCClient.shared.query("campaign.getUserBalance")
            balance = result

        } catch {}
    }
}

// MARK: - View

struct CampaignMarketplaceView: View {
    @Environment(\.appColors) private var colors
    @Environment(SessionManager.self) private var sessionManager

    @State private var viewModel = CampaignMarketplaceViewModel()
    @State private var appeared = false

    private var displayName: String {
        let u = sessionManager.currentUser
        return u?.username ?? u?.name ?? u?.email ?? ""
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [colors.bg, colors.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, Layout.pagePadX)
                        .padding(.vertical, 12)

                    // Balance card
                    balanceCard(viewModel.balance)
                        .padding(.horizontal, Layout.pagePadX)

                    // Invite banner
                    inviteBanner
                        .padding(.horizontal, Layout.pagePadX)
                        .padding(.top, 16)

                    // Section header
                    HStack {
                        Text("Recommended campaigns")
                            .font(AppFont.Display.semibold(14))
                            .foregroundColor(colors.text)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("See all")
                                .font(AppFont.Body.medium(13))
                                .foregroundColor(colors.accent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(colors.accent)
                        }
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    // Campaign list
                    if viewModel.isLoading && viewModel.campaigns.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in CampaignSkeletonCard() }
                        }
                        .padding(.horizontal, Layout.pagePadX)
                    } else if let err = viewModel.error {
                        VStack(spacing: 12) {
                            Text(err)
                                .font(AppFont.Body.regular(14))
                                .foregroundColor(colors.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await viewModel.load() } }
                                .font(AppFont.Body.semibold(14))
                                .foregroundColor(colors.accent)
                        }
                        .padding(.horizontal, Layout.pagePadX)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.campaigns.enumerated()), id: \.element.id) { index, campaign in
                                NavigationLink(value: campaign.id) {
                                    CampaignCard(campaign: campaign, colors: colors)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 16)
                                        .animation(
                                            .cardAppear.delay(Double(min(index, 5)) * 0.04),
                                            value: appeared
                                        )
                                }
                                .buttonStyle(PressableButtonStyle())
                                .onAppear {
                                    if index == viewModel.campaigns.count - 2 {
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

                    Spacer(minLength: 100)
                }
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
            // Logo icon (red triangle play mark)
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Welcome back")
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.textSecondary)
                Text(displayName.isEmpty ? "..." : displayName)
                    .font(AppFont.Body.semibold(16))
                    .foregroundColor(colors.text)
            }

            Spacer()
        }
    }

    // MARK: - Balance Card

    private func balanceCard(_ balance: BalanceBreakdown = .zero) -> some View {
        ZStack {
            LinearGradient(
                colors: [colors.accent, colors.accentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))

            VStack(alignment: .leading, spacing: 16) {
                // Top row: balance + details
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avail. Balance")
                            .font(AppFont.Body.medium(14))
                            .foregroundColor(.white)
                        Text(balance.formattedTotal)
                            .font(AppFont.Body.bold(32))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    NavigationLink(value: "wallet") {
                        HStack(spacing: 6) {
                            Image(systemName: "wallet.bifold")
                                .font(.system(size: 14))
                            Text("Details")
                                .font(AppFont.Body.medium(13))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                }

                // Sub cards
                HStack(spacing: 8) {
                    miniCard(title: "Total Earned", value: balance.formattedOwed, valueColor: Palette.Green.g600)
                    miniCard(title: "In Review", value: balance.formattedInReview, valueColor: Palette.Amber.a700)
                }
            }
            .padding(20)
        }
        .frame(height: 155)
    }

    private func miniCard(title: String, value: String, valueColor: Color) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.80), Color.white.opacity(0.90)],
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppFont.Body.regular(12))
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

    // MARK: - Invite Banner

    private var inviteBanner: some View {
        LinearGradient(
            colors: [Palette.Mint.m100, Palette.Green.g100],
            startPoint: .leading,
            endPoint: .trailing
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Palette.Mint.m400)
                        .frame(width: 36, height: 36)
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Several brands have invited you!")
                        .font(AppFont.Body.medium(14))
                        .foregroundColor(Palette.Mint.m950)
                    Text("Join their invite-only campaign now.")
                        .font(AppFont.Body.regular(12))
                        .foregroundColor(Palette.Mint.m950)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Palette.Mint.m950)
            }
            .padding(16)
        )
        .frame(height: 68)
    }
}

// MARK: - Campaign Card (matches RN design: compact, no thumbnail)

struct CampaignCard: View {
    let campaign: Campaign
    let colors: AppColors

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: brand logo + title + meta + platform icons
            HStack(spacing: 12) {
                // Brand avatar
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color(hex: campaign.brandColor ?? "#CE1111"))
                        .frame(width: 40, height: 40)
                    if let logoURL = campaign.brandLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                EmptyView()
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    } else {
                        Text(String(campaign.brandName.prefix(1)).uppercased())
                            .font(AppFont.Body.bold(18))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 40, height: 40)

                // Title + meta
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.name)
                        .font(AppFont.Body.semibold(15))
                        .foregroundColor(colors.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(campaign.brandName)
                            .font(AppFont.Body.medium(12))
                            .foregroundColor(colors.textSecondary)
                            .lineLimit(1)
                        if !campaign.endsInLabel.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(colors.textTertiary)
                            Text(campaign.endsInLabel)
                                .font(AppFont.Body.medium(12))
                                .foregroundColor(colors.textSecondary)
                        }
                        Spacer()
                        PlatformIconRow(platforms: campaign.platforms, size: 16, color: colors.iconSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Dotted separator
            DottedLine()
                .stroke(colors.divider, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .frame(height: 1)
                .padding(.vertical, 8)

            // Budget info + percentage
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(campaign.formattedPaidAmount) of \(campaign.formattedBudget) paid")
                            .font(AppFont.Body.medium(13))
                            .foregroundColor(colors.text)
                        if !campaign.endsInLabel.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(colors.textTertiary)
                            Text(campaign.endsInLabel)
                                .font(AppFont.Body.regular(12))
                                .foregroundColor(colors.textSecondary)
                        }
                    }
                }
                Spacer()
                Text("\(Int(campaign.spentPercent))%")
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.text)
            }

            // Progress bar
            SegmentedProgressBar(percentage: campaign.spentPercent, colors: colors)
                .padding(.top, 8)
        }
        .padding(16)
        .background(colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(colors.borderSecondary, lineWidth: 1)
        )
    }
}

// MARK: - Dotted Line Shape

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Segmented Progress Bar

struct SegmentedProgressBar: View {
    let percentage: Double
    let colors: AppColors
    private let totalSegments = 45
    private let fullHeight: CGFloat = 18

    var body: some View {
        let pct = min(100, max(0, percentage))
        let filled = Int((pct / 100.0) * Double(totalSegments))
        let emptyCount = max(1, totalSegments - filled)

        HStack(spacing: 3) {
            ForEach(0..<totalSegments, id: \.self) { i in
                let isFilled = i < filled
                // Empty segments taper in height from 100% → ~55% as they get further from the fill point
                let emptyIdx = isFilled ? 0 : (i - filled)
                let heightRatio: CGFloat = isFilled
                    ? 1.0
                    : max(0.55, 1.0 - CGFloat(emptyIdx) / CGFloat(emptyCount) * 0.45)

                Capsule()
                    .fill(isFilled ? colors.progressFilled : colors.progressEmpty)
                    .frame(height: fullHeight * heightRatio)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: fullHeight)
    }
}

// MARK: - Skeleton Card

struct CampaignSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SkeletonRect(cornerRadius: Radius.md, height: 40).frame(width: 40)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonRect(height: 14).frame(maxWidth: .infinity)
                    SkeletonRect(height: 12).frame(maxWidth: 160)
                }
            }
            SkeletonRect(height: 1)
            SkeletonRect(height: 12).frame(maxWidth: 200)
            SkeletonRect(height: 4)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Palette.Sand.s200, lineWidth: 1))
    }
}
