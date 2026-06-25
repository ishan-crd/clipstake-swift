import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Referrals View Model

@Observable
@MainActor final class ReferralsViewModel {
    var overview: ReferralOverview?
    var referrals: [ReferralRow] = []
    var isLoading = false
    var isRefreshing = false
    var copied = false
    var error: AppError?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await fetchAll()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await fetchAll()
    }

    private func fetchAll() async {
        do {
            async let ovTask: ReferralOverview = TRPCClient.shared.query("referral.getOverview")
            async let listTask: [ReferralRow] = TRPCClient.shared.query("referral.listReferrals")
            let (ov, list) = try await (ovTask, listTask)
            overview = ov
            referrals = list
        } catch let err as AppError {
            error = err
        } catch {
            self.error = .unknown(error)
        }
    }

    func copyCode() {
        guard let code = overview?.code else { return }
#if os(iOS)
        UIPasteboard.general.string = code
#endif
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { self.copied = false }
        }
    }

    func shareCode() {
        guard let code = overview?.code else { return }
        let url = "https://clipstake.com/onboarding?ref=\(code)"
        let message = "Join me on Clipstake and start earning. Use my code \(code): \(url)"
#if os(iOS)
        let av = UIActivityViewController(activityItems: [message, URL(string: url)!] as [Any], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
#endif
    }
}

// MARK: - View

struct ReferralsView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReferralsViewModel()

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
                        Text("Referrals")
                            .font(AppFont.Display.bold(20))
                            .foregroundColor(colors.text)
                            .frame(maxWidth: .infinity)
                        Spacer().frame(width: 32)
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 16)

                    // Referral code card
                    if let ov = viewModel.overview {
                        referralCodeCard(ov)
                            .padding(.horizontal, Layout.pagePadX)

                        // Stats
                        statsRow(ov)
                            .padding(.horizontal, Layout.pagePadX)
                    } else if viewModel.isLoading {
                        SkeletonRect(height: 140).padding(.horizontal, Layout.pagePadX)
                        SkeletonRect(height: 60).padding(.horizontal, Layout.pagePadX)
                    }

                    // Referred users
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Referred creators")
                            .font(AppFont.Display.semibold(16))
                            .foregroundColor(colors.text)
                            .padding(.horizontal, Layout.pagePadX)

                        if viewModel.referrals.isEmpty && !viewModel.isLoading {
                            referralsEmptyState
                        } else if viewModel.isLoading {
                            VStack(spacing: 1) {
                                ForEach(0..<3, id: \.self) { _ in SkeletonRect(height: 56) }
                            }
                            .padding(.horizontal, Layout.pagePadX)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(viewModel.referrals) { row in
                                    ReferralUserRow(row: row, colors: colors)
                                    if row.id != viewModel.referrals.last?.id {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .background(colors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .padding(.horizontal, Layout.pagePadX)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .refreshable { await viewModel.refresh() }
        }
        .navigationBarHidden(true)
        .task { await viewModel.load() }
    }

    // MARK: - Referral Code Card

    private func referralCodeCard(_ ov: ReferralOverview) -> some View {
        ZStack {
            LinearGradient(
                colors: [Palette.Mint.m500, Palette.Mint.m600],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.white)
                    Text("Your referral code")
                        .font(AppFont.Body.medium(14))
                        .foregroundColor(.white.opacity(0.85))
                }

                Text(ov.code ?? "—")
                    .font(AppFont.Display.bold(32))
                    .foregroundColor(.white)
                    .tracking(4)

                HStack(spacing: 10) {
                    Button { viewModel.copyCode() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.copied ? "checkmark" : "doc.on.doc")
                            Text(viewModel.copied ? "Copied!" : "Copy")
                        }
                        .font(AppFont.Body.medium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .animation(.conditional, value: viewModel.copied)

                    Button { viewModel.shareCode() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(AppFont.Body.medium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(20)
        )
        .frame(minHeight: 160)
    }

    // MARK: - Stats Row

    private func statsRow(_ ov: ReferralOverview) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(ov.totalReferrals)")
                    .font(AppFont.Display.bold(24))
                    .foregroundColor(colors.text)
                Text("Referrals")
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(ov.formattedEarnings)
                    .font(AppFont.Display.bold(24))
                    .foregroundColor(colors.success)
                Text("Total earned")
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: - Empty State

    private var referralsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.system(size: 40))
                .foregroundColor(colors.textTertiary)
            Text("No referrals yet")
                .font(AppFont.Display.semibold(16))
                .foregroundColor(colors.text)
            Text("Share your code and start earning 1% of your referrals' payouts for 12 months.")
                .font(AppFont.Body.regular(13))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .padding(.horizontal, Layout.pagePadX)
    }
}

// MARK: - Referral User Row

private struct ReferralUserRow: View {
    let row: ReferralRow
    let colors: AppColors

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(colors.bgSecondary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(row.name.prefix(1)).uppercased())
                        .font(AppFont.Body.semibold(14))
                        .foregroundColor(colors.textSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(AppFont.Body.medium(14))
                    .foregroundColor(colors.text)
                HStack(spacing: 8) {
                    if let username = row.username {
                        Text("@\(username)")
                            .font(AppFont.Body.regular(12))
                            .foregroundColor(colors.textSecondary)
                    }
                    Text(row.roleLabel)
                        .font(AppFont.Body.regular(11))
                        .foregroundColor(colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colors.bgSecondary)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.formattedEarnings)
                    .font(AppFont.Body.semibold(13))
                    .foregroundColor(colors.success)
                Text(row.formattedDate)
                    .font(AppFont.Body.regular(11))
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
