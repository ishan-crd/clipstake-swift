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
            group.addTask { await self.fetchUserSubmissions() }
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
            await fetchUserSubmissions()
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

    private func fetchUserSubmissions() async {
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

// MARK: - Submit Clip Bottom Sheet

struct SubmitClipSheet: View {
    @Bindable var viewModel: CampaignDetailViewModel
    @Binding var isPresented: Bool
    @Environment(\.appColors) private var colors
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Submit a clip")
                        .font(AppFont.Display.bold(20))
                        .foregroundColor(colors.text)
                    if let campaign = viewModel.campaign {
                        Text(campaign.title)
                            .font(AppFont.Body.regular(13))
                            .foregroundColor(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(colors.bgSecondary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Video URL")
                            .font(AppFont.Body.semibold(13))
                            .foregroundColor(colors.text)

                        HStack(spacing: 10) {
                            if let platform = viewModel.detectedPlatform {
                                PlatformIconRow(platforms: [platform], size: 18, color: colors.accent)
                                    .frame(width: 22)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 16))
                                    .foregroundColor(colors.textTertiary)
                                    .frame(width: 22)
                            }

                            TextField("Paste your video URL here", text: Binding(
                                get: { viewModel.videoURL },
                                set: { viewModel.onURLChange($0) }
                            ))
                            .font(AppFont.Body.regular(14))
                            .foregroundColor(colors.text)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($urlFocused)

                            if !viewModel.videoURL.isEmpty {
                                Button {
                                    viewModel.onURLChange("")
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(colors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(colors.bgInput)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(
                                    viewModel.submitError != nil ? colors.error :
                                    viewModel.submitSuccess ? colors.success :
                                    urlFocused ? colors.accent :
                                    colors.border,
                                    lineWidth: 1
                                )
                        )

                        // Platform detection hint
                        if let platform = viewModel.detectedPlatform {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.success)
                                Text("\(platform.capitalized) URL detected")
                                    .font(AppFont.Body.regular(13))
                                    .foregroundColor(colors.success)
                            }
                        }
                    }

                    // Error
                    if let err = viewModel.submitError {
                        HStack(spacing: 6) {
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
                    }

                    // Success
                    if viewModel.submitSuccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(colors.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clip submitted!")
                                    .font(AppFont.Body.semibold(14))
                                    .foregroundColor(colors.success)
                                Text("We'll review it and update your workspace.")
                                    .font(AppFont.Body.regular(12))
                                    .foregroundColor(colors.textSecondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colors.success.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    // Info row
                    if let campaign = viewModel.campaign, !campaign.cpmLabel.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(colors.textTertiary)
                            Text("Earn \(campaign.cpmLabel) once your clip is approved.")
                                .font(AppFont.Body.regular(12))
                                .foregroundColor(colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }

            // Bottom buttons
            VStack(spacing: 10) {
                Button {
                    Task {
                        await viewModel.submitClip()
                        if viewModel.submitSuccess {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            isPresented = false
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit clip")
                                .font(AppFont.Body.semibold(16))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(viewModel.isSubmitting ? Palette.Crimson.c600.opacity(0.7) : Palette.Crimson.c600)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(viewModel.isSubmitting || viewModel.videoURL.trimmingCharacters(in: .whitespaces).isEmpty)

                Button { isPresented = false } label: {
                    Text("Cancel")
                        .font(AppFont.Body.medium(14))
                        .foregroundColor(colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(colors.bg)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { urlFocused = true }
        }
    }
}

// MARK: - Helpers

private func formatViews(_ views: Int) -> String {
    if views >= 1_000_000 { return String(format: "%.1fM", Double(views) / 1_000_000) }
    if views >= 1_000     { return String(format: "%.1fK", Double(views) / 1_000) }
    return "\(views)"
}
