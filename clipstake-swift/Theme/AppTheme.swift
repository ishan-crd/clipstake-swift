import SwiftUI

// MARK: - Raw Palette

enum Palette {
    enum Sand {
        static let s50  = Color(hex: "#fafaf9")
        static let s100 = Color(hex: "#f1efea")
        static let s200 = Color(hex: "#e7e5e4")
        static let s300 = Color(hex: "#d6d3d1")
        static let s400 = Color(hex: "#a6a09b")
        static let s500 = Color(hex: "#79716b")
        static let s600 = Color(hex: "#57534d")
        static let s700 = Color(hex: "#44403b")
        static let s800 = Color(hex: "#312c2b")
        static let s900 = Color(hex: "#24211e")
        static let s950 = Color(hex: "#14110f")
    }
    enum Crimson {
        static let c50  = Color(hex: "#fae7e7")
        static let c100 = Color(hex: "#f5cfcf")
        static let c200 = Color(hex: "#f0b8b8")
        static let c300 = Color(hex: "#e27070")
        static let c400 = Color(hex: "#d84141")
        static let c500 = Color(hex: "#ce1111")
        static let c600 = Color(hex: "#a50e0e")
        static let c700 = Color(hex: "#7c0a0a")
        static let c800 = Color(hex: "#520707")
        static let c900 = Color(hex: "#3e0505")
        static let c950 = Color(hex: "#290303")
    }
    enum Mint {
        static let m50  = Color(hex: "#c7fff0")
        static let m100 = Color(hex: "#c0e9e1")
        static let m200 = Color(hex: "#96dad0")
        static let m300 = Color(hex: "#60c7b8")
        static let m400 = Color(hex: "#2cb2a1")
        static let m500 = Color(hex: "#009e86")
        static let m600 = Color(hex: "#008c76")
        static let m700 = Color(hex: "#007461")
        static let m800 = Color(hex: "#005b4c")
        static let m900 = Color(hex: "#004038")
        static let m950 = Color(hex: "#002a25")
    }
    enum Green {
        static let g100 = Color(hex: "#dcfce7")
        static let g500 = Color(hex: "#22c55e")
        static let g600 = Color(hex: "#16a34a")
        static let g700 = Color(hex: "#15803d")
        static let g900 = Color(hex: "#14532d")
    }
    enum Cyan {
        static let c50  = Color(hex: "#ecfeff")
        static let c400 = Color(hex: "#22d3ee")
        static let c600 = Color(hex: "#0891b2")
        static let c950 = Color(hex: "#083344")
    }
    enum Amber {
        static let a700 = Color(hex: "#b45309")
    }
    static let errorRed   = Color(hex: "#ef4444")
    static let red50      = Color(hex: "#fef2f2")
}

// MARK: - Semantic Tokens

struct AppColors {
    let bg: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let bgAccent: Color
    let bgAccentRed: Color
    let bgCard: Color
    let bgInput: Color
    let bgOverlay: Color

    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverse: Color

    let border: Color
    let borderSecondary: Color
    let borderAccent: Color

    let accent: Color
    let accentDark: Color

    let success: Color
    let error: Color
    let info: Color
    let bgInfo: Color

    let tabBarBorder: Color
    let divider: Color
    let iconDefault: Color
    let iconSecondary: Color
    let searchBg: Color

    let progressFilled: Color
    let progressEmpty: Color
    let bgProgress: Color
    let textProgress: Color

    let tabBar: Color

    let loginBg: Color
    let oauthBg: Color
    let oauthBorder: Color
    let oauthText: Color
}

// MARK: - Light & Dark Instances

extension AppColors {
    static let light = AppColors(
        bg:             Palette.Sand.s50,
        bgSecondary:    Palette.Sand.s100,
        bgTertiary:     Palette.Sand.s200,
        bgAccent:       Palette.Crimson.c50,
        bgAccentRed:    Palette.errorRed.opacity(0.05),
        bgCard:         .white,
        bgInput:        .white,
        bgOverlay:      Color.black.opacity(0.5),
        text:           Palette.Sand.s900,
        textSecondary:  Palette.Sand.s500,
        textTertiary:   Palette.Sand.s400,
        textInverse:    Palette.Sand.s50,
        border:         Palette.Sand.s100,
        borderSecondary: Palette.Sand.s200,
        borderAccent:   Palette.Green.g100,
        accent:         Palette.Crimson.c500,
        accentDark:     Palette.Crimson.c600,
        success:        Palette.Green.g600,
        error:          Palette.errorRed,
        info:           Palette.Cyan.c600,
        bgInfo:         Palette.Cyan.c50,
        tabBarBorder:   Palette.Sand.s200,
        divider:        Palette.Sand.s200,
        iconDefault:    Palette.Sand.s700,
        iconSecondary:  Palette.Sand.s500,
        searchBg:       Palette.Sand.s100,
        progressFilled: Palette.Mint.m400,
        progressEmpty:  Palette.Mint.m100,
        bgProgress:     Palette.Mint.m100,
        textProgress:   Palette.Mint.m700,
        tabBar:         .white,
        loginBg:        Palette.Crimson.c50,
        oauthBg:        Palette.Sand.s50,
        oauthBorder:    Palette.Sand.s200,
        oauthText:      Palette.Sand.s600
    )

    static let dark = AppColors(
        bg:             Palette.Sand.s950,
        bgSecondary:    Palette.Sand.s900,
        bgTertiary:     Palette.Sand.s800,
        bgAccent:       Palette.Crimson.c950,
        bgAccentRed:    Palette.Crimson.c950,
        bgCard:         Palette.Sand.s900,
        bgInput:        Palette.Sand.s800,
        bgOverlay:      Color.black.opacity(0.7),
        text:           Palette.Sand.s100,
        textSecondary:  Palette.Sand.s400,
        textTertiary:   Palette.Sand.s500,
        textInverse:    Palette.Sand.s50,
        border:         Palette.Sand.s800,
        borderSecondary: Palette.Sand.s700,
        borderAccent:   Palette.Green.g900,
        accent:         Palette.Crimson.c400,
        accentDark:     Palette.Crimson.c500,
        success:        Palette.Green.g500,
        error:          Palette.errorRed,
        info:           Palette.Cyan.c400,
        bgInfo:         Palette.Cyan.c950,
        tabBarBorder:   Palette.Sand.s800,
        divider:        Palette.Sand.s800,
        iconDefault:    Palette.Sand.s300,
        iconSecondary:  Palette.Sand.s400,
        searchBg:       Palette.Sand.s800,
        progressFilled: Palette.Mint.m400,
        progressEmpty:  Palette.Mint.m950,
        bgProgress:     Palette.Mint.m950,
        textProgress:   Palette.Mint.m200,
        tabBar:         Palette.Sand.s950,
        loginBg:        Palette.Sand.s950,
        oauthBg:        Palette.Sand.s900,
        oauthBorder:    Palette.Sand.s700,
        oauthText:      Palette.Sand.s300
    )
}

// MARK: - Static (never flip with dark mode)

extension AppColors {
    static let activeTabIconLight = Palette.Sand.s100
    static let activeTabIconDark  = Color.white
    static let onBrandWhite       = Color.white
}

// MARK: - Environment Key

private struct AppColorsKey: EnvironmentKey {
    static let defaultValue: AppColors = .light
}

extension EnvironmentValues {
    var appColors: AppColors {
        get { self[AppColorsKey.self] }
        set { self[AppColorsKey.self] = newValue }
    }
}

// MARK: - Font System

enum AppFont {
    enum Display {
        static func regular(_ size: CGFloat) -> Font { .custom("StackSansNotch-Regular", size: size) }
        static func medium(_ size: CGFloat) -> Font  { .custom("StackSansNotch-Medium", size: size) }
        static func semibold(_ size: CGFloat) -> Font { .custom("StackSansNotch-SemiBold", size: size) }
        static func bold(_ size: CGFloat) -> Font    { .custom("StackSansNotch-Bold", size: size) }
    }
    enum Body {
        static func regular(_ size: CGFloat) -> Font  { .custom("Inter-Regular", size: size) }
        static func medium(_ size: CGFloat) -> Font   { .custom("Inter-Medium", size: size) }
        static func semibold(_ size: CGFloat) -> Font { .custom("Inter-SemiBold", size: size) }
        static func bold(_ size: CGFloat) -> Font     { .custom("Inter-Bold", size: size) }
    }
}

// MARK: - Color(hex:) extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
