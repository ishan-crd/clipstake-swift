import SwiftUI

// MARK: - Campaign Detail View Model

@Observable
@MainActor final class CampaignDetailViewModel {
    let campaignId: String
    var campaign: Campaign?
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
        guard !urlTrimmed.isEmpty else {
            submitError = "Please enter a video URL."
            return
        }
        guard urlTrimmed.isValidURL else {
            submitError = "Please enter a valid URL."
            return
        }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            struct SubmitInput: Encodable { let campaignId: String; let videoUrl: String }
            let _: Submission = try await TRPCClient.shared.mutate(
                "submission.submit",
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
            let c: Campaign = try await TRPCClient.shared.query("campaign.getById", input: Input(id: campaignId))
            campaign = c
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }

    private func fetchUserSubmissions() async {
        do {
            struct Input: Encodable { let campaignId: String }
            let subs: [Submission] = try await TRPCClient.shared.query(
                "submission.list",
                input: Input(campaignId: campaignId)
            )
            submissions = subs
        } catch {}
    }
}

// MARK: - View

struct CampaignDetailView: View {
    let campaignId: String

    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CampaignDetailViewModel

    init(campaignId: String) {
        self.campaignId = campaignId
        self._viewModel = State(initialValue: CampaignDetailViewModel(campaignId: campaignId))
    }

    var body: some View {
        ZStack {
            colors.bg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    if let campaign = viewModel.campaign {
                        // Hero thumbnail
                        heroSection(campaign)

                        // Campaign details
                        campaignInfo(campaign)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.top, 20)

                        Divider()
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.vertical, 16)

                        // Submit section
                        submitSection
                            .padding(.horizontal, Layout.pagePadX)

                        // User's existing submissions
                        if !viewModel.submissions.isEmpty {
                            Divider()
                                .padding(.horizontal, Layout.pagePadX)
                                .padding(.vertical, 16)

                            submissionsSection
                                .padding(.horizontal, Layout.pagePadX)
                        }

                    } else if viewModel.isLoading {
                        skeletonDetail
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            navigationBar
        }
        .task { await viewModel.load() }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colors.text)
                    .frame(width: 40, height: 40)
                    .background(colors.bgCard.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()
        }
        .padding(.horizontal, Layout.pagePadX)
        .padding(.top, 8)
    }

    // MARK: - Hero

    private func heroSection(_ campaign: Campaign) -> some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: campaign.thumbnailURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    Rectangle().fill(colors.bgTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)

            HStack(alignment: .bottom) {
                // Brand logo + name
                HStack(spacing: 8) {
                    if let logoURL = campaign.brandLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Circle().fill(colors.bgSecondary)
                            }
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    }
                    Text(campaign.brandName ?? "")
                        .font(AppFont.Body.medium(13))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()

                // Status badge
                statusBadge(campaign.status)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let (bg, fg): (Color, Color) = switch status {
        case "active":    (Palette.Green.g500.opacity(0.2), Palette.Green.g500)
        case "paused":    (Color.orange.opacity(0.2),       Color.orange)
        case "completed": (colors.bgTertiary,               colors.textSecondary)
        default:          (colors.bgTertiary,               colors.textSecondary)
        }

        Text(status.capitalized)
            .font(AppFont.Body.medium(11))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Campaign Info

    private func campaignInfo(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(campaign.title)
                .font(AppFont.Display.bold(22))
                .foregroundColor(colors.text)

            if let desc = campaign.description, !desc.isEmpty {
                Text(desc)
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(nil)
            }

            // Platforms
            VStack(alignment: .leading, spacing: 8) {
                Text("Accepted platforms")
                    .font(AppFont.Body.semibold(13))
                    .foregroundColor(colors.text)
                PlatformIconRow(platforms: campaign.platforms, size: 20, color: colors.iconSecondary)
            }

            // CPM info
            HStack(spacing: 16) {
                infoChip(label: "CPM", value: campaign.cpmLabel ?? "\(campaign.cpmCents / 100)¢")
                infoChip(label: "Budget", value: campaign.formattedBudget)
                if !campaign.endsInLabel.isEmpty {
                    infoChip(label: "Deadline", value: campaign.endsInLabel)
                }
            }
        }
    }

    private func infoChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.Body.regular(11))
                .foregroundColor(colors.textTertiary)
            Text(value)
                .font(AppFont.Body.semibold(13))
                .foregroundColor(colors.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(colors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Submit a clip")
                .font(AppFont.Display.semibold(16))
                .foregroundColor(colors.text)

            // URL input
            HStack(spacing: 10) {
                if let platform = viewModel.detectedPlatform {
                    PlatformIconRow(platforms: [platform], size: 18, color: colors.accent)
                        .frame(width: 20)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 16))
                        .foregroundColor(colors.textTertiary)
                        .frame(width: 20)
                }

                TextField("Paste video URL", text: Binding(
                    get: { viewModel.videoURL },
                    set: { viewModel.onURLChange($0) }
                ))
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.text)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            }
            .padding()
            .background(colors.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        viewModel.submitError != nil ? colors.error :
                        viewModel.submitSuccess ? colors.success :
                        colors.border,
                        lineWidth: 1
                    )
            )

            // Error / success messages
            if let err = viewModel.submitError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13))
                    Text(err)
                        .font(AppFont.Body.regular(13))
                }
                .foregroundColor(colors.error)
            }

            if viewModel.submitSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text("Clip submitted successfully!")
                        .font(AppFont.Body.regular(13))
                }
                .foregroundColor(colors.success)
                .transition(.opacity.combined(with: .scale))
            }

            // Submit button
            Button {
                Task { await viewModel.submitClip() }
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
                .frame(height: 50)
                .background(colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .opacity(viewModel.isSubmitting ? 0.7 : 1)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.isSubmitting)
        }
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

    private var skeletonDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            SkeletonRect(height: 220)
            SkeletonRect(height: 28).padding(.horizontal, Layout.pagePadX)
            SkeletonRect(height: 16).padding(.horizontal, Layout.pagePadX).frame(maxWidth: 300)
            SkeletonRect(height: 16).padding(.horizontal, Layout.pagePadX).frame(maxWidth: 250)
        }
    }
}
