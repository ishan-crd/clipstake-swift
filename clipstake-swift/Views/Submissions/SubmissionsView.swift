import SwiftUI

// MARK: - Submissions View Model

@Observable
@MainActor final class SubmissionsViewModel {
    var submissions: [Submission] = []
    var isLoading = false
    var isRefreshing = false
    var error: AppError?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        await fetch()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await fetch()
    }

    private func fetch() async {
        do {
            let result: [Submission] = try await TRPCClient.shared.query("submission.list")
            submissions = result
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }
}

// MARK: - View

struct SubmissionsView: View {
    @Environment(\.appColors) private var colors
    @State private var viewModel = SubmissionsViewModel()

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
                        Text("My Submissions")
                            .font(AppFont.Display.bold(24))
                            .foregroundColor(colors.text)
                        Spacer()
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    if viewModel.isLoading && viewModel.submissions.isEmpty {
                        VStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonRect(height: 72).padding(.horizontal, Layout.pagePadX)
                            }
                        }
                    } else if viewModel.submissions.isEmpty {
                        SubmissionsEmptyState(colors: colors)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(viewModel.submissions) { sub in
                                NavigationLink(value: sub.id) {
                                    SubmissionFlatRow(submission: sub, colors: colors)
                                }
                                .buttonStyle(PressableButtonStyle())

                                if sub.id != viewModel.submissions.last?.id {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(colors.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .padding(.horizontal, Layout.pagePadX)
                    }

                    Spacer(minLength: 100)
                }
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: String.self) { _ in EmptyView() }
        }
        .navigationBarHidden(true)
        .task { await viewModel.load() }
    }
}

// MARK: - Flat Submission Row

private struct SubmissionFlatRow: View {
    let submission: Submission
    let colors: AppColors

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: submission.thumbnailURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    Rectangle().fill(colors.bgTertiary)
                        .overlay(Image(systemName: "film").foregroundColor(colors.textTertiary))
                }
            }
            .frame(width: 64, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: 4) {
                Text(submission.campaignTitle ?? "Campaign")
                    .font(AppFont.Body.medium(13))
                    .foregroundColor(colors.text)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label(submission.formattedViews, systemImage: "eye")
                        .font(AppFont.Body.regular(11))
                        .foregroundColor(colors.textSecondary)
                    Label(submission.formattedPayout, systemImage: "dollarsign")
                        .font(AppFont.Body.regular(11))
                        .foregroundColor(colors.success)
                }
            }

            Spacer()

            StatusBadge(status: submission.statusColor, label: submission.status, colors: colors)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

private struct SubmissionsEmptyState: View {
    let colors: AppColors

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(colors.textTertiary)
            Text("No submissions yet")
                .font(AppFont.Display.semibold(18))
                .foregroundColor(colors.text)
            Text("Submit a clip to a campaign to get started.")
                .font(AppFont.Body.regular(14))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
