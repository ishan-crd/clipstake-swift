import SwiftUI

// MARK: - Campaign Detail View Model

@Observable
@MainActor final class CampaignDetailViewModel {
    let campaignId: String
    var campaign: CampaignDetail?
    var submissions: [Submission] = []
    var isLoading = false
    var isSubmitting = false
    var videoURL = ""
    var detectedPlatform: String?
    var submitError: String?
    var submitSuccess = false
    var error: AppError?

    init(campaignId: String) {
        self.campaignId = campaignId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCampaign() }
            group.addTask { await self.fetchSubmissionsPublic() }
        }
    }

    func onURLChange(_ url: String) {
        videoURL = url
        detectedPlatform = url.detectPlatform()
        submitError = nil
        submitSuccess = false
    }

    func submitClip() async {
        let urlTrimmed = videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlTrimmed.isEmpty else { submitError = "Please enter a video URL."; return }
        guard urlTrimmed.isValidURL   else { submitError = "Please enter a valid URL."; return }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            struct SubmitInput: Encodable { let campaignId: String; let videoUrl: String }
            let _: Submission = try await TRPCClient.shared.mutate(
                "submission.create",
                input: SubmitInput(campaignId: campaignId, videoUrl: urlTrimmed)
            )
            videoURL = ""
            detectedPlatform = nil
            submitSuccess = true
            await fetchSubmissionsPublic()
        } catch AppError.duplicate {
            submitError = "You've already submitted this video."
        } catch let err as AppError {
            submitError = err.errorDescription
        } catch {
            submitError = error.localizedDescription
        }
    }

    private func fetchCampaign() async {
        do {
            struct Input: Encodable { let id: String }
            let c: CampaignDetail = try await TRPCClient.shared.query(
                "campaign.getCampaignDetail",
                input: Input(id: campaignId)
            )
            campaign = c
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }

    func fetchSubmissionsPublic() async {
        do {
            let subs: [Submission] = try await TRPCClient.shared.query("submission.list")
            submissions = subs
        } catch {}
    }
}

// MARK: - Tab

private enum CampaignTab: String, CaseIterable {
    case general     = "General"
    case guidelines  = "Guidelines"
    case cpm         = "CPM"
    case leaderboard = "Leaderboard"
}

// MARK: - View

struct CampaignDetailView: View {
    let campaignId: String

    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CampaignDetailViewModel
    @State private var selectedTab: CampaignTab = .general
    @State private var showSubmitSheet = false

    init(campaignId: String) {
        self.campaignId = campaignId
        self._viewModel = State(initialValue: CampaignDetailViewModel(campaignId: campaignId))
    }

    var body: some View {
        ZStack {
            colors.bg.ignoresSafeArea()

            if let campaign = viewModel.campaign {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(campaign)
                        metaSection(campaign)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.top, 14)
                        budgetSection(campaign)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.top, 12)
                        submitButton
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.top, 16)
                        tabBar
                            .padding(.top, 16)
                        tabContent(campaign)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.top, 16)
                        if !viewModel.submissions.isEmpty {
                            submissionsSection
                                .padding(.horizontal, Layout.pagePadX)
                                .padding(.top, 24)
                        }
                        Spacer(minLength: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if viewModel.isLoading {
                skeletonView
            } else if let err = viewModel.error {
                VStack(spacing: 12) {
                    Text(err.errorDescription ?? "Error loading campaign")
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.load() } }
                        .font(AppFont.Body.semibold(14))
                        .foregroundColor(colors.accent)
                }
                .padding(32)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSubmitSheet) {
            SubmitClipSheet(viewModel: viewModel, isPresented: $showSubmitSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(
                    LinearGradient(
                        colors: [.white, Palette.Sand.s100],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .task { await viewModel.load() }
    }

    // MARK: - Hero

    private func heroSection(_ campaign: CampaignDetail) -> some View {
        ZStack(alignment: .bottom) {
            // Thumbnail
            GeometryReader { geo in
                AsyncImage(url: campaign.thumbnailURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(hex: campaign.brandColor))
                    }
                }
                .frame(width: geo.size.width, height: 260)
                .clipped()
            }
            .frame(height: 260)

            // Gradient scrim at bottom
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)

            // Bottom overlay: brand logo + badges
            HStack(alignment: .bottom, spacing: 10) {
                brandLogo(campaign)
                Spacer()
                HStack(spacing: 6) {
                    if campaign.status == "active" {
                        heroBadge("Active", fg: Palette.Green.g600, bg: Palette.Green.g100)
                    } else if campaign.status == "paused" {
                        heroBadge("Paused", fg: .orange, bg: Color.orange.opacity(0.2))
                    }
                    if campaign.requiresLogo == true {
                        heroBadge("Logo", fg: Palette.Sand.s600, bg: Color.white.opacity(0.85))
                    }
                    if campaign.isPrivate == true {
                        heroBadge("Private", fg: Palette.Sand.s600, bg: Color.white.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Top overlay: back button + CPM pill
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    Spacer()
                    if !campaign.cpmLabel.isEmpty {
                        Text(campaign.cpmLabel)
                            .font(AppFont.Body.medium(12))
                            .foregroundColor(colors.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                Spacer()
            }
        }
        .frame(height: 260)
    }

    private func brandLogo(_ campaign: CampaignDetail) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: campaign.brandColor))
                .frame(width: 44, height: 44)
            if let logoURL = campaign.brandLogoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else { EmptyView() }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Text(String(campaign.brandName.prefix(1)).uppercased())
                    .font(AppFont.Body.bold(18))
                    .foregroundColor(.white)
            }
        }
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }

    private func heroBadge(_ label: String, fg: Color, bg: Color) -> some View {
        Text(label)
            .font(AppFont.Body.medium(11))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Meta (title + platforms + countdown)

    private func metaSection(_ campaign: CampaignDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(campaign.title)
                .font(AppFont.Display.bold(22))
                .foregroundColor(colors.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PlatformIconRow(platforms: campaign.platforms, size: 18, color: colors.iconSecondary)
                Spacer()
                if let endDate = campaign.endDateParsed {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(colors.textTertiary)
                        CountdownText(endDate: endDate)
                            .font(AppFont.Body.medium(12))
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Budget

    private func budgetSection(_ campaign: CampaignDetail) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                Text("\(campaign.formattedSpent) of \(campaign.formattedBudget) paid")
                    .font(AppFont.Body.medium(13))
                    .foregroundColor(colors.text)
                Spacer()
                if !campaign.formattedTotalViews.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                            .foregroundColor(colors.textTertiary)
                        Text(campaign.formattedTotalViews)
                            .font(AppFont.Body.regular(12))
                            .foregroundColor(colors.textSecondary)
                    }
                }
                Text("\(Int(campaign.budgetPercentage))%")
                    .font(AppFont.Body.medium(13))
                    .foregroundColor(colors.text)
                    .padding(.leading, 8)
            }
            SegmentedProgressBar(percentage: campaign.budgetPercentage, colors: colors)
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button { showSubmitSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .semibold))
                Text("Submit a clip")
                    .font(AppFont.Body.semibold(16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Palette.Crimson.c600)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(CampaignTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(selectedTab == tab ? AppFont.Body.semibold(13) : AppFont.Body.regular(13))
                                .foregroundColor(selectedTab == tab ? colors.text : colors.textSecondary)
                            Rectangle()
                                .fill(selectedTab == tab ? colors.accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Divider()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ campaign: CampaignDetail) -> some View {
        switch selectedTab {
        case .general:    generalTab(campaign)
        case .guidelines: guidelinesTab(campaign)
        case .cpm:        cpmTab(campaign)
        case .leaderboard: leaderboardTab
        }
    }

    private func generalTab(_ campaign: CampaignDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // About
            if let desc = campaign.descriptionText, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About campaign")
                        .font(AppFont.Display.semibold(16))
                        .foregroundColor(colors.text)
                    Text(desc)
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Resources
            if let resources = campaign.resources, !resources.isEmpty {
                HStack(spacing: 10) {
                    ForEach(resources, id: \.url) { resource in
                        if let url = URL(string: resource.url) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 13))
                                    Text(resource.name)
                                        .font(AppFont.Body.medium(13))
                                }
                                .foregroundColor(colors.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(colors.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.md)
                                        .stroke(colors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    if let website = campaign.websiteUrl, let url = URL(string: website) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Text("Visit website")
                                    .font(AppFont.Body.medium(13))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(colors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(colors.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(colors.border, lineWidth: 1)
                            )
                        }
                    }
                    Spacer()
                }
            } else if let website = campaign.websiteUrl, let url = URL(string: website) {
                HStack {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("Visit website")
                                .font(AppFont.Body.medium(13))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(colors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(colors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(colors.border, lineWidth: 1)
                        )
                    }
                    Spacer()
                }
            }
        }
    }

    private func guidelinesTab(_ campaign: CampaignDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let instructions = campaign.campaignInstructions, !instructions.isEmpty {
                Text("Campaign Guidelines")
                    .font(AppFont.Display.semibold(16))
                    .foregroundColor(colors.text)
                Text(instructions)
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                emptyTabState(icon: "doc.text", message: "No guidelines provided for this campaign.")
            }
        }
    }

    private func cpmTab(_ campaign: CampaignDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earnings")
                .font(AppFont.Display.semibold(16))
                .foregroundColor(colors.text)

            VStack(spacing: 1) {
                if let p = campaign.payPer1kViews {
                    cpmRow(label: "Pay per 1k views", value: campaign.cpmLabel)
                    Divider()
                    cpmRow(label: "CPM (cents)", value: "\(p)¢")
                }
                if let min = campaign.minViews {
                    Divider()
                    cpmRow(label: "Min. views to qualify", value: formatViews(min))
                }
                if let max = campaign.maxPayoutPerVideo {
                    Divider()
                    cpmRow(label: "Max payout / video", value: "$\(String(format: "%.2f", Double(max) / 100))")
                }
            }
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
    }

    private func cpmRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.Body.regular(13))
                .foregroundColor(colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.Body.semibold(13))
                .foregroundColor(colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var leaderboardTab: some View {
        emptyTabState(icon: "trophy", message: "Leaderboard coming soon.")
    }

    private func emptyTabState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(colors.textTertiary)
            Text(message)
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Submissions Section

    private var submissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your submissions")
                .font(AppFont.Display.semibold(16))
                .foregroundColor(colors.text)
            VStack(spacing: 1) {
                ForEach(viewModel.submissions) { sub in
                    SubmissionRow(submission: sub, colors: colors)
                    if sub.id != viewModel.submissions.last?.id {
                        Divider().padding(.leading, 88)
                    }
                }
            }
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SkeletonRect(height: 260)
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRect(height: 26).frame(maxWidth: .infinity)
                    SkeletonRect(height: 18).frame(maxWidth: 220)
                    SkeletonRect(height: 14)
                    SkeletonRect(height: 50).padding(.top, 4)
                }
                .padding(.horizontal, Layout.pagePadX)
                .padding(.top, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Countdown Text

private struct CountdownText: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(countdownString(from: endDate, now: context.date))
        }
    }

    private func countdownString(from date: Date, now: Date) -> String {
        let diff = max(0, date.timeIntervalSince(now))
        if diff == 0 { return "Ended" }
        let totalSeconds = Int(diff)
        let days    = totalSeconds / 86400
        let hours   = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02dD : %02dH : %02dM : %02dS", days, hours, minutes, seconds)
    }
}

// MARK: - Submit Clip Bottom Sheet (2-step)

private enum SubmitStep { case info, input }

struct SubmitClipSheet: View {
    @Bindable var viewModel: CampaignDetailViewModel
    @Binding var isPresented: Bool
    @Environment(\.appColors) private var colors

    @State private var step: SubmitStep = .info
    @State private var addedURLs: [String] = []
    @State private var currentInput: String = ""
    @FocusState private var inputFocused: Bool
    @State private var submitError: String?
    @State private var isSubmitting = false

    private let maxVideos = 5

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            switch step {
            case .info:
                infoStep
            case .input:
                inputStep
            }
        }
        .background(.clear)
    }

    // MARK: - Shared Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            // X dismiss
            HStack {
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Palette.Sand.s100)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Text("Submit your clips")
                .font(AppFont.Display.bold(20))
                .foregroundColor(colors.text)

            Text("Post your video first, then paste the\nlink here within 1 hour.")
                .font(AppFont.Body.regular(13))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Info

    private var infoStep: some View {
        VStack(spacing: 0) {
            Divider()

            if let campaign = viewModel.campaign {
                infoRow(label: "Minimum views",
                        value: campaign.minViews.map { formatCompact($0) } ?? "—")
                Divider().padding(.leading, 16)

                infoRow(label: "Maximum submissions",
                        value: campaign.maxSubmissions.map { "\($0)" } ?? "—")
                Divider().padding(.leading, 16)

                if let p = campaign.payPer1kViews {
                    infoRow(label: "Rate per 1K Views",
                            value: "\(stripCents(p)) USD",
                            valueColor: Palette.Green.g600)
                    Divider().padding(.leading, 16)
                }

                if let max = campaign.maxPayoutPerVideo {
                    infoRow(label: "Maximum payout",
                            value: "\(stripCents(max)) USD",
                            valueColor: Palette.Green.g600)
                    Divider().padding(.leading, 16)
                }

                // Platform row
                HStack {
                    Text("Platform")
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(campaign.platforms, id: \.self) { p in
                            platformBadge(p)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider()

            Spacer(minLength: 0)

            // I understand button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { step = .input }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { inputFocused = true }
            } label: {
                HStack(spacing: 8) {
                    Text("I understand")
                        .font(AppFont.Body.semibold(16))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Palette.Crimson.c600)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private func infoRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.Body.medium(14))
                .foregroundColor(valueColor ?? colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func platformBadge(_ platform: String) -> some View {
        HStack(spacing: 4) {
            PlatformIconRow(platforms: [platform], size: 14, color: colors.text)
            Text(platform.platformDisplayName)
                .font(AppFont.Body.medium(12))
                .foregroundColor(colors.text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.Sand.s100)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    // MARK: - Step 2: Input

    private var inputStep: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Section header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Submit videos")
                            .font(AppFont.Body.medium(14))
                            .foregroundColor(Palette.Sand.s800)
                        let total = viewModel.campaign?.maxClipsTotal ?? viewModel.campaign?.maxSubmissions
                        if let t = total {
                            Text("This campaign accepts up to \(t) clips total.")
                                .font(AppFont.Body.regular(13))
                                .foregroundColor(colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Error banner
                    if let err = submitError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                            Text(err)
                                .font(AppFont.Body.regular(13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(colors.error)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colors.error.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    // Added URL chips
                    VStack(spacing: 8) {
                        ForEach(addedURLs.indices, id: \.self) { i in
                            urlChip(url: addedURLs[i]) {
                                addedURLs.remove(at: i)
                            }
                        }

                        // Active input field (if under max)
                        if addedURLs.count < maxVideos {
                            urlInputField
                        }
                    }
                    .padding(.horizontal, 16)

                    // Add another button
                    if addedURLs.count < maxVideos - 1 || (!currentInput.isEmpty && addedURLs.count < maxVideos) {
                        let slotCount = addedURLs.count + (addedURLs.isEmpty ? 1 : (currentInput.isEmpty ? 0 : 1))
                        Button {
                            let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && trimmed.isValidURL {
                                addedURLs.append(trimmed)
                                currentInput = ""
                                submitError = nil
                            } else if !trimmed.isEmpty {
                                submitError = "Please enter a valid URL."
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { inputFocused = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Add another video")
                                    .font(AppFont.Body.medium(14))
                                Text("(\(slotCount)/\(maxVideos))")
                                    .font(AppFont.Body.regular(13))
                                    .foregroundColor(colors.textTertiary)
                            }
                            .foregroundColor(colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Palette.Sand.s100)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(Palette.Sand.s200, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 24)
                }
            }

            // Submit button
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await handleSubmit() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit")
                                .font(AppFont.Body.semibold(16))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? Palette.Crimson.c600 : Palette.Crimson.c600.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canSubmit || isSubmitting)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { inputFocused = true }
        }
    }

    // MARK: - URL Input Field

    private var urlInputField: some View {
        HStack(spacing: 10) {
            if let platform = currentInput.detectPlatform() {
                PlatformIconRow(platforms: [platform], size: 16, color: colors.textSecondary)
                    .frame(width: 18)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(colors.textTertiary)
                    .frame(width: 18)
            }

            TextField("Enter a link to your video", text: $currentInput)
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.text)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($inputFocused)
                .onChange(of: currentInput) { _, _ in submitError = nil }

            if !currentInput.isEmpty {
                Button { currentInput = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Palette.Sand.s300)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(inputFocused ? Palette.Crimson.c300 : Palette.Sand.s200, lineWidth: 1)
        )
    }

    // MARK: - URL Chip Row

    private func urlChip(url: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(url)
                .font(AppFont.Body.regular(13))
                .foregroundColor(colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let platform = url.detectPlatform() {
                HStack(spacing: 4) {
                    PlatformIconRow(platforms: [platform], size: 13, color: colors.text)
                    Text(platform.platformDisplayName)
                        .font(AppFont.Body.medium(12))
                        .foregroundColor(colors.text)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Palette.Sand.s100)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Palette.Crimson.c500)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.Sand.s200, lineWidth: 1)
        )
    }

    // MARK: - Submit Logic

    private var canSubmit: Bool {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !addedURLs.isEmpty || (!trimmed.isEmpty && trimmed.isValidURL)
    }

    private func handleSubmit() async {
        var allURLs = addedURLs
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard trimmed.isValidURL else { submitError = "Please enter a valid URL."; return }
            allURLs.append(trimmed)
        }
        guard !allURLs.isEmpty else { submitError = "Please enter at least one video URL."; return }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        var lastError: String?
        for url in allURLs {
            do {
                struct SubmitInput: Encodable { let campaignId: String; let videoUrl: String }
                let _: Submission = try await TRPCClient.shared.mutate(
                    "submission.create",
                    input: SubmitInput(campaignId: viewModel.campaignId, videoUrl: url)
                )
            } catch AppError.duplicate {
                lastError = "One or more videos were already submitted."
            } catch let err as AppError {
                lastError = err.errorDescription
            } catch {
                lastError = error.localizedDescription
            }
        }

        if let err = lastError {
            submitError = err
        } else {
            await viewModel.fetchSubmissionsPublic()
            try? await Task.sleep(nanoseconds: 500_000_000)
            isPresented = false
        }
    }
}

// MARK: - Helpers

private func stripCents(_ cents: Int) -> String {
    let dollars = Double(cents) / 100.0
    var str = String(format: "%.2f", dollars)
    while str.hasSuffix("0") { str.removeLast() }
    if str.hasSuffix(".") { str.removeLast() }
    return "$\(str)"
}

private func formatCompact(_ n: Int) -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    return nf.string(from: NSNumber(value: n)) ?? "\(n)"
}

private func formatViews(_ views: Int) -> String {
    if views >= 1_000_000 { return String(format: "%.1fM", Double(views) / 1_000_000) }
    if views >= 1_000     { return String(format: "%.1fK", Double(views) / 1_000) }
    return "\(views)"
}
