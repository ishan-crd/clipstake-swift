import Foundation

// MARK: - User

struct AppUser: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let email: String
    var username: String?
    var image: String?
    let role: String
    let status: String?
    let referralCode: String?
}

// MARK: - Campaign

struct Campaign: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let status: String
    let budgetCents: Int
    let remainingBudgetCents: Int
    let cpmCents: Int
    let maxPayoutPerVideo: Int?
    let endsAt: String?
    let thumbnail: String?
    let category: String?
    let platforms: [String]
    let submissionCount: Int
    let totalViewCount: Int
    let brandName: String?
    let brandLogo: String?
    let brandColor: String?
    let cpmLabel: String?

    var thumbnailURL: URL? {
        guard let t = thumbnail else { return nil }
        if t.hasPrefix("http") { return URL(string: t) }
        return URL(string: "https://cdn.clipstake.com/\(t)")
    }

    var brandLogoURL: URL? {
        guard let l = brandLogo else { return nil }
        if l.hasPrefix("http") { return URL(string: l) }
        return URL(string: "https://cdn.clipstake.com/\(l)")
    }

    var budgetPercentage: Double {
        guard budgetCents > 0 else { return 0 }
        let spent = budgetCents - remainingBudgetCents
        return Double(spent) / Double(budgetCents) * 100
    }

    var endsInLabel: String {
        guard let iso = endsAt else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let diff = date.timeIntervalSinceNow
        if diff <= 0 { return "Ended" }
        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "ends in \(days)d" }
        return "ends in \(hours)h"
    }

    var formattedBudget: String { formatDollars(budgetCents) }
    var formattedRemaining: String { formatDollars(remainingBudgetCents) }
}

// MARK: - Submission

struct Submission: Codable, Identifiable {
    let id: String
    let campaignId: String
    let platform: String
    let status: String
    let views: Int
    let payoutCents: Int
    let thumbnailUrl: String?
    let createdAt: String?
    let campaignTitle: String?
    let campaignThumbnail: String?

    var thumbnailURL: URL? {
        guard let t = thumbnailUrl else { return nil }
        return URL(string: t)
    }

    var campaignThumbnailURL: URL? {
        guard let t = campaignThumbnail else { return nil }
        if t.hasPrefix("http") { return URL(string: t) }
        return URL(string: "https://cdn.clipstake.com/\(t)")
    }

    var statusColor: StatusColor {
        switch status {
        case "pending":       .amber
        case "approved":      .green
        case "rejected":      .red
        case "paid":          .mint
        case "not_qualified": .gray
        default:              .gray
        }
    }

    var formattedViews: String { formatViews(views) }
    var formattedPayout: String { formatDollars(payoutCents) }
}

enum StatusColor {
    case amber, green, red, mint, gray
}

// MARK: - Balance

struct BalanceBreakdown: Codable {
    let userWalletCents: Int
    let creatorOwedCents: Int
    let referrerOwedCents: Int

    var totalCents: Int { userWalletCents + creatorOwedCents + referrerOwedCents }
    var formattedTotal: String { formatDollars(totalCents) }
    var formattedWallet: String { formatDollars(userWalletCents) }
    var formattedOwed: String { formatDollars(creatorOwedCents) }
    var formattedReferrer: String { formatDollars(referrerOwedCents) }
}

// MARK: - Referrals

struct ReferralOverview: Codable {
    let code: String?
    let totalReferrals: Int
    let totalEarningsCents: Int

    var formattedEarnings: String { formatDollars(totalEarningsCents) }
}

struct ReferralRow: Codable, Identifiable {
    let id: String
    let name: String
    let username: String?
    let role: String
    let referredAt: String?
    let earningsCents: Int

    var formattedEarnings: String { formatDollars(earningsCents) }
    var formattedDate: String {
        guard let iso = referredAt else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
    var roleLabel: String {
        switch role {
        case "creator": "Creator"
        case "org", "agency": "Brand"
        default: role.capitalized
        }
    }
}

// MARK: - Transactions

struct Transaction: Codable, Identifiable {
    let id: String
    let kind: String
    let amountCents: Int
    let status: String
    let description: String?
    let occurredAt: String?

    var formattedAmount: String { formatDollars(amountCents) }
    var formattedDate: String {
        guard let iso = occurredAt else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

// MARK: - Paginated Response

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let nextCursor: String?
    let hasMore: Bool?
}

// MARK: - Profile Upload

struct PresignedUrlResponse: Codable {
    let url: String
    let key: String
}

// MARK: - Errors

enum AppError: Error, LocalizedError {
    case network(URLError)
    case trpc(code: String, message: String)
    case unauthorized
    case notCreator
    case duplicate
    case deactivated
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let e):           return e.localizedDescription
        case .trpc(_, let msg):         return msg
        case .unauthorized:             return "Please sign in again."
        case .notCreator:               return "This app is for creators only."
        case .duplicate:                return "You've already submitted this video."
        case .deactivated:              return "Your account has been deactivated."
        case .unknown(let e):           return e.localizedDescription
        }
    }
}

// MARK: - Helpers

private func formatDollars(_ cents: Int) -> String {
    let value = Double(cents) / 100.0
    return String(format: "$%.2f", value)
}

private func formatViews(_ views: Int) -> String {
    if views >= 1_000_000 { return String(format: "%.1fM", Double(views) / 1_000_000) }
    if views >= 1_000     { return String(format: "%.1fK", Double(views) / 1_000) }
    return "\(views)"
}
