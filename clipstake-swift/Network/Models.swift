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
// Field names match the `campaign.listMarketplace` tRPC response exactly.

struct Campaign: Codable, Identifiable {
    let id: String
    let name: String
    let thumbnailUrl: String?
    let brandName: String
    let brandColor: String?
    let brandLogo: String?
    let status: String
    let category: String?
    let cpmDollars: Double
    let spentDollars: Double
    let budgetDollars: Double
    let spentPercent: Double
    let endDate: String?
    let platforms: [String]

    // Backward-compat aliases used by other views
    var title: String { name }
    var thumbnail: String? { thumbnailUrl }
    var cpmCents: Int { Int(cpmDollars * 100) }

    var thumbnailURL: URL? {
        guard let t = thumbnailUrl, !t.isEmpty else { return nil }
        if t.hasPrefix("http") { return URL(string: t) }
        return URL(string: "https://cdn.clipstake.com/\(t)")
    }

    var brandLogoURL: URL? {
        guard let l = brandLogo, !l.isEmpty else { return nil }
        if l.hasPrefix("http") { return URL(string: l) }
        return URL(string: "https://cdn.clipstake.com/\(l)")
    }

    var budgetPercentage: Double { spentPercent }

    var endsInLabel: String {
        guard let iso = endDate, !iso.isEmpty else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let diff = date.timeIntervalSinceNow
        if diff <= 0 { return "Ended" }
        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "ends in \(days)d" }
        return "ends in \(hours)h"
    }

    var cpmLabel: String { "$\(String(format: "%.2f", cpmDollars)) / 1k views" }
    var formattedBudget: String { "$\(String(format: "%.2f", budgetDollars))" }
    var formattedPaidAmount: String { "$\(String(format: "%.2f", spentDollars))" }
    var formattedRemaining: String { "$\(String(format: "%.2f", max(0, budgetDollars - spentDollars)))" }
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
// Field names match the `campaign.getUserBalance` tRPC response exactly.

struct BalanceBreakdown: Codable {
    let availableCents: Int
    let totalBalanceCents: Int
    let withdrawableBalanceCents: Int

    static let zero = BalanceBreakdown(availableCents: 0, totalBalanceCents: 0, withdrawableBalanceCents: 0)

    var inReviewCents: Int { max(0, withdrawableBalanceCents - availableCents) }

    var formattedTotal: String { formatDollars(availableCents) }
    var formattedOwed: String { formatDollars(totalBalanceCents) }
    var formattedInReview: String { formatDollars(inReviewCents) }

    // Backward-compat aliases used by WalletView
    var formattedWallet: String { formatDollars(withdrawableBalanceCents) }
    var formattedReferrer: String { "$0.00" }
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

// MARK: - Campaign Detail
// Matches the `campaign.getCampaignDetail` tRPC response (different shape from listMarketplace).

struct CampaignDetail: Codable, Identifiable {
    let id: String
    let name: String
    let thumbnailUrl: String?
    let brand: Brand?
    let status: String
    let category: String?
    let description: String?
    let campaignAbout: String?
    let endDate: String?
    let platforms: [String]
    let budgetDollars: Double?
    let spentDollars: Double?
    let spentPercent: Double?
    let payPer1kViews: Int?
    let minViews: Int?
    let maxPayoutPerVideo: Int?
    let resources: [CampaignResource]?
    let campaignInstructions: String?

    struct Brand: Codable {
        let name: String?
        let primaryColor: String?
        let logoPath: String?
    }

    struct CampaignResource: Codable {
        let name: String
        let url: String
    }

    var title: String { name }
    var brandName: String { brand?.name ?? "" }
    var brandColor: String { brand?.primaryColor ?? "#CE1111" }

    var thumbnailURL: URL? {
        guard let t = thumbnailUrl, !t.isEmpty else { return nil }
        return t.hasPrefix("http") ? URL(string: t) : URL(string: "https://cdn.clipstake.com/\(t)")
    }
    var brandLogoURL: URL? {
        guard let l = brand?.logoPath, !l.isEmpty else { return nil }
        return l.hasPrefix("http") ? URL(string: l) : URL(string: "https://cdn.clipstake.com/\(l)")
    }

    var descriptionText: String? { campaignAbout ?? description }

    var endsInLabel: String {
        guard let iso = endDate, !iso.isEmpty else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        let diff = date.timeIntervalSinceNow
        if diff <= 0 { return "Ended" }
        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        return days > 0 ? "ends in \(days)d" : "ends in \(hours)h"
    }

    var cpmLabel: String {
        guard let p = payPer1kViews else { return "" }
        return "$\(String(format: "%.2f", Double(p) / 100)) / 1k views"
    }
    var formattedBudget: String {
        "$\(String(format: "%.2f", budgetDollars ?? 0))"
    }
    var budgetPercentage: Double { spentPercent ?? 0 }
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
