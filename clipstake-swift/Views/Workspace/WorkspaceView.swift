import SwiftUI

// MARK: - Workspace View Model

@Observable
@MainActor final class WorkspaceViewModel {
    var campaigns: [WorkspaceCampaign] = []
    var isLoading = false
    var isRefreshing = false
    var error: AppError?

    struct WorkspaceCampaign: Identifiable {
        let id: String
        let title: String
        let thumbnail: String?
        let submissions: [Submission]
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        await fetchSubmissions()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await fetchSubmissions()
    }

    private func fetchSubmissions() async {
        do {
            let subs: [Submission] = try await TRPCClient.shared.query("submission.list")
            groupSubmissions(subs)
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }

    private func groupSubmissions(_ subs: [Submission]) {
        var map: [(String, String?, String?, [Submission])] = []
        var seen: [String: Int] = [:]
        for sub in subs {
            let cid = sub.campaignId
            if let idx = seen[cid] {
                map[idx].3.append(sub)
            } else {
                seen[cid] = map.count
                map.append((cid, sub.campaignTitle, sub.campaignThumbnail, [sub]))
            }
        }
        campaigns = map.map { WorkspaceCampaign(id: $0.0, title: $0.1 ?? "Campaign", thumbnail: $0.2, submissions: $0.3) }
    }
}

// MARK: - View

struct WorkspaceView: View {
    @Environment(\.appColors) private var colors
    @State private var viewModel = WorkspaceViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.bg, colors.bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Workspace")
                            .font(AppFont.Display.bold(24))
                            .foregroundColor(colors.text)
                        Spacer()
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    if viewModel.isLoading && viewModel.campaigns.isEmpty {
                        VStack(spacing: 20) {
                            ForEach(0..<2, id: \.self) { _ in WorkspaceSkeletonSection() }
                        }
                        .padding(.horizontal, Layout.pagePadX)
                    } else if viewModel.campaigns.isEmpty {
                        WorkspaceEmptyState(colors: colors)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.campaigns) { campaign in
                                WorkspaceCampaignSection(campaign: campaign, colors: colors)
                            }
                        }
                        .padding(.horizontal, Layout.pagePadX)
                    }

                    Spacer(minLength: 100)
                }
            }
            .refreshable { await viewModel.refresh() }
        }
        .navigationBarHidden(true)
        .task { await viewModel.load() }
    }
}

// MARK: - Campaign Section

private struct WorkspaceCampaignSection: View {
    let campaign: WorkspaceViewModel.WorkspaceCampaign
    let colors: AppColors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 10) {
                AsyncImage(url: campaign.thumbnail.flatMap { t in
                    URL(string: t.hasPrefix("http") ? t : "https://cdn.clipstake.com/\(t)")
                }) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(colors.bgTertiary)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                Text(campaign.title)
                    .font(AppFont.Body.semibold(14))
                    .foregroundColor(colors.text)
                    .lineLimit(1)

                Spacer()

                Text("\(campaign.submissions.count) clip\(campaign.submissions.count == 1 ? "" : "s")")
                    .font(AppFont.Body.regular(12))
                    .foregroundColor(colors.textSecondary)
            }

            // Submission rows
            VStack(spacing: 1) {
                ForEach(campaign.submissions) { sub in
                    NavigationLink(value: sub.id) {
                        SubmissionRow(submission: sub, colors: colors)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .navigationDestination(for: String.self) { _ in EmptyView() }
    }
}

// MARK: - Submission Row

struct SubmissionRow: View {
    let submission: Submission
    let colors: AppColors

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: submission.thumbnailURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    Rectangle().fill(colors.bgTertiary)
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(colors.textTertiary)
                        )
                }
            }
            .frame(width: 64, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                        .foregroundColor(colors.textTertiary)
                    Text(submission.formattedViews)
                        .font(AppFont.Body.medium(13))
                        .foregroundColor(colors.text)
                }
                Text(submission.formattedPayout)
                    .font(AppFont.Body.regular(12))
                    .foregroundColor(colors.success)
            }

            Spacer()

            StatusBadge(status: submission.statusColor, label: submission.status.capitalized, colors: colors)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: StatusColor
    let label: String
    let colors: AppColors

    private var displayLabel: String {
        switch label.lowercased() {
        case "not_qualified": "Not Qualified"
        default: label.capitalized
        }
    }

    var body: some View {
        Text(displayLabel)
            .font(AppFont.Body.medium(11))
            .foregroundColor(colors.statusForeground(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colors.statusBackground(for: status))
            .clipShape(Capsule())
    }
}

// MARK: - Empty State

private struct WorkspaceEmptyState: View {
    let colors: AppColors

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(colors.textTertiary)
            Text("No submissions yet")
                .font(AppFont.Display.semibold(18))
                .foregroundColor(colors.text)
            Text("Browse campaigns in the marketplace and submit your first clip.")
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Skeleton

private struct WorkspaceSkeletonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonRect(height: 20).frame(maxWidth: 200)
            VStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRect(height: 60)
                }
            }
        }
    }
}
