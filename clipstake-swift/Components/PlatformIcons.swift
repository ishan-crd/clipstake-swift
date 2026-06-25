import SwiftUI

// MARK: - Platform Icon Views

struct TikTokIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

struct InstagramIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        Image(systemName: "camera")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

struct YouTubeIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        Image(systemName: "play.rectangle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

struct XIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        Image(systemName: "bird")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

// MARK: - Platform Icon Row

struct PlatformIconRow: View {
    let platforms: [String]
    var size: CGFloat = 16
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            ForEach(platforms, id: \.self) { platform in
                platformIcon(platform)
            }
        }
    }

    @ViewBuilder
    private func platformIcon(_ platform: String) -> some View {
        switch platform.lowercased() {
        case "tiktok":
            TikTokIcon(size: size, color: color)
        case "instagram":
            InstagramIcon(size: size, color: color)
        case "youtube":
            YouTubeIcon(size: size, color: color)
        case "twitter", "x":
            XIcon(size: size, color: color)
        default:
            Image(systemName: "play.circle")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(color)
        }
    }
}

// MARK: - Platform Name

extension String {
    var platformDisplayName: String {
        switch lowercased() {
        case "tiktok":    "TikTok"
        case "instagram": "Instagram"
        case "youtube":   "YouTube"
        case "twitter", "x": "X"
        default: capitalized
        }
    }
}
