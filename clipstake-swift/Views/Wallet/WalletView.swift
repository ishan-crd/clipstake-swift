import SwiftUI

// MARK: - Wallet View Model

@Observable
@MainActor final class WalletViewModel {
    var balance: BalanceBreakdown?
    var transactions: [Transaction] = []
    var isLoading = false
    var isRefreshing = false
    var error: AppError?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchBalance() }
            group.addTask { await self.fetchTransactions() }
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchBalance() }
            group.addTask { await self.fetchTransactions() }
        }
    }

    private func fetchBalance() async {
        do {
            let result: BalanceBreakdown = try await TRPCClient.shared.query("campaign.loadUserBalanceBreakdown")
            balance = result
        } catch {}
    }

    private func fetchTransactions() async {
        do {
            let result: [Transaction] = try await TRPCClient.shared.query("transaction.listForUser")
            transactions = result
        } catch {}
    }
}

// MARK: - View

struct WalletView: View {
    @Environment(\.appColors) private var colors
    @State private var viewModel = WalletViewModel()

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
                        Text("Wallet")
                            .font(AppFont.Display.bold(24))
                            .foregroundColor(colors.text)
                        Spacer()
                    }
                    .padding(.horizontal, Layout.pagePadX)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Balance card
                    if let balance = viewModel.balance {
                        BalanceCard(balance: balance, colors: colors)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.bottom, 20)
                    } else if viewModel.isLoading {
                        SkeletonRect(height: 200)
                            .padding(.horizontal, Layout.pagePadX)
                            .padding(.bottom, 20)
                    }

                    // Transactions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction history")
                            .font(AppFont.Display.semibold(16))
                            .foregroundColor(colors.text)
                            .padding(.horizontal, Layout.pagePadX)

                        if viewModel.isLoading && viewModel.transactions.isEmpty {
                            VStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { _ in
                                    SkeletonRect(height: 60)
                                }
                            }
                            .padding(.horizontal, Layout.pagePadX)
                        } else if viewModel.transactions.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 36))
                                    .foregroundColor(colors.textTertiary)
                                Text("No transactions yet")
                                    .font(AppFont.Body.regular(14))
                                    .foregroundColor(colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(viewModel.transactions) { tx in
                                    TransactionRow(transaction: tx, colors: colors)
                                    if tx.id != viewModel.transactions.last?.id {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(colors.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .padding(.horizontal, Layout.pagePadX)
                        }
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

// MARK: - Balance Card

private struct BalanceCard: View {
    let balance: BalanceBreakdown
    let colors: AppColors

    var body: some View {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Balance")
                        .font(AppFont.Body.medium(13))
                        .foregroundColor(AppColors.onBrandWhite.opacity(0.8))
                    Text(balance.formattedTotal)
                        .font(AppFont.Display.bold(36))
                        .foregroundColor(AppColors.onBrandWhite)
                }

                Divider().background(Color.white.opacity(0.3))

                VStack(spacing: 10) {
                    balanceRow("Wallet", value: balance.formattedWallet)
                    balanceRow("Pending Payouts", value: balance.formattedOwed)
                    balanceRow("Referral Earnings", value: balance.formattedReferrer)
                }
            }
            .padding(20)
        )
        .frame(minHeight: 200)
    }

    private func balanceRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.Body.regular(13))
                .foregroundColor(AppColors.onBrandWhite.opacity(0.75))
            Spacer()
            Text(value)
                .font(AppFont.Body.medium(13))
                .foregroundColor(AppColors.onBrandWhite)
        }
    }
}

// MARK: - Transaction Row

private struct TransactionRow: View {
    let transaction: Transaction
    let colors: AppColors

    private var iconName: String {
        switch transaction.kind {
        case "deposit":           "arrow.down.circle.fill"
        case "payout", "payout_out": "arrow.up.circle.fill"
        case "referral", "referral_out": "person.2.fill"
        default:                  "circle.fill"
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case "deposit", "payout", "referral": colors.success
        default: colors.error
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(amountColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description ?? transaction.kind.capitalized)
                    .font(AppFont.Body.medium(13))
                    .foregroundColor(colors.text)
                    .lineLimit(1)
                Text(transaction.formattedDate)
                    .font(AppFont.Body.regular(11))
                    .foregroundColor(colors.textTertiary)
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(AppFont.Body.semibold(14))
                .foregroundColor(amountColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}
