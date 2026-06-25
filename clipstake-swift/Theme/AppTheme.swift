import SwiftUI

// MARK: - Raw Palette
// Exact values from tooling/tailwind/theme.css

enum Palette {

    // MARK: Sand
    enum Sand {
        static let s50  = Color(hex: "#faf9f7") // Sand-50
        static let s100 = Color(hex: "#f1efea") // Sand-100
        static let s200 = Color(hex: "#e3ded3") // Sand-200
        static let s300 = Color(hex: "#d1c9bb") // Sand-300
        static let s400 = Color(hex: "#b8ae9e") // Sand-400
        static let s500 = Color(hex: "#79716b") // Sand-500
        static let s600 = Color(hex: "#57534d") // Sand-600
        static let s700 = Color(hex: "#44403b") // Sand-700
        static let s800 = Color(hex: "#312c2b") // Sand-800
        static let s900 = Color(hex: "#24211e") // Sand-900
        static let s950 = Color(hex: "#14110f") // Sand-950
    }

    // MARK: Crimson
    enum Crimson {
        static let c50   = Color(hex: "#fae7e7") // --color-crimson-50
        static let c100  = Color(hex: "#f5cfcf") // --color-crimson-100
        static let c200  = Color(hex: "#f0b8b8") // --color-crimson-200
        static let c300  = Color(hex: "#e27070") // --color-crimson-300
        static let c400  = Color(hex: "#d84141") // --color-crimson-400
        static let c500  = Color(hex: "#ce1111") // --color-crimson-500
        static let c600  = Color(hex: "#a50e0e") // --color-crimson-600
        static let c700  = Color(hex: "#7c0a0a") // --color-crimson-700
        static let c800  = Color(hex: "#520707") // --color-crimson-800
        static let c900  = Color(hex: "#3e0505") // --color-crimson-900
        static let c950  = Color(hex: "#290303") // --color-crimson-950
        static let c1000 = Color(hex: "#150202") // --color-crimson-1000
    }

    // MARK: Mint
    enum Mint {
        static let m50  = Color(hex: "#c7fff0") // --color-mint-50
        static let m100 = Color(hex: "#c0e9e1") // --color-mint-100
        static let m200 = Color(hex: "#96dad0") // --color-mint-200
        static let m300 = Color(hex: "#60c7b8") // --color-mint-300
        static let m400 = Color(hex: "#2cb2a1") // --color-mint-400
        static let m500 = Color(hex: "#009e86") // --color-mint-500
        static let m600 = Color(hex: "#008c76") // --color-mint-600
        static let m700 = Color(hex: "#007461") // --color-mint-700
        static let m800 = Color(hex: "#005b4c") // --color-mint-800
        static let m900 = Color(hex: "#004038") // --color-mint-900
        static let m950 = Color(hex: "#002a25") // --color-mint-950
    }

    // MARK: Neutral
    enum Neutral {
        static let n50  = Color(hex: "#fafafa") // --color-neutral-50
        static let n100 = Color(hex: "#f4f4f5") // --color-neutral-100
        static let n200 = Color(hex: "#e4e4e7") // --color-neutral-200
        static let n300 = Color(hex: "#d4d4d8") // --color-neutral-300
        static let n400 = Color(hex: "#a1a1aa") // --color-neutral-400
        static let n500 = Color(hex: "#71717a") // --color-neutral-500
        static let n600 = Color(hex: "#52525b") // --color-neutral-600
        static let n700 = Color(hex: "#3f3f46") // --color-neutral-700
        static let n800 = Color(hex: "#27272a") // --color-neutral-800
        static let n900 = Color(hex: "#18181b") // --color-neutral-900
        static let n950 = Color(hex: "#09090b") // --color-neutral-950
    }

    // MARK: Alpha Light (neutral scale for light surfaces)
    enum AlphaLight {
        static let a0   = Color(hex: "#ffffff") // --color-alpha-light-0
        static let a5   = Color(hex: "#f7f7f8") // --color-alpha-light-5
        static let a10  = Color(hex: "#f1f1f2") // --color-alpha-light-10
        static let a20  = Color(hex: "#e6e6e8") // --color-alpha-light-20
        static let a30  = Color(hex: "#dbdbde") // --color-alpha-light-30
        static let a50  = Color(hex: "#c4c4c9") // --color-alpha-light-50
        static let a80  = Color(hex: "#a1a1a9") // --color-alpha-light-80
        static let a100 = Color(hex: "#8b8b94") // --color-alpha-light-100
    }

    // MARK: Alpha Dark (neutral scale for dark surfaces)
    enum AlphaDark {
        static let a0   = Color(hex: "#0b0b0c") // --color-alpha-dark-0
        static let a10  = Color(hex: "#18181a") // --color-alpha-dark-10
        static let a20  = Color(hex: "#252527") // --color-alpha-dark-20
        static let a25  = Color(hex: "#2c2c2e") // --color-alpha-dark-25
        static let a30  = Color(hex: "#323235") // --color-alpha-dark-30
        static let a35  = Color(hex: "#39393b") // --color-alpha-dark-35
        static let a50  = Color(hex: "#4c4c4f") // --color-alpha-dark-50
        static let a80  = Color(hex: "#737376") // --color-alpha-dark-80
        static let a100 = Color(hex: "#8d8d90") // --color-alpha-dark-100
    }

    // MARK: Green (used for success states & progress bars)
    enum Green {
        static let g50  = Color(hex: "#f0fdf4") // Green-50
        static let g100 = Color(hex: "#dcfce7") // Green-100
        static let g200 = Color(hex: "#bbf7d0") // Green-200
        static let g300 = Color(hex: "#86efac") // Green-300
        static let g400 = Color(hex: "#4ade80") // Green-400
        static let g500 = Color(hex: "#22c55e") // Green-500
        static let g600 = Color(hex: "#16a34a") // Green-600
        static let g700 = Color(hex: "#15803d") // Green-700
        static let g800 = Color(hex: "#166534") // Green-800
        static let g900 = Color(hex: "#14532d") // Green-900
        static let g950 = Color(hex: "#052e16") // Green-950
    }

    // MARK: Amber (Tailwind — used for warning/review states)
    enum Amber {
        static let a100 = Color(hex: "#fef3c7")
        static let a400 = Color(hex: "#fbbf24")
        static let a700 = Color(hex: "#b45309")
    }
}

// MARK: - Semantic Tokens

struct AppColors {
    // Backgrounds
    let bg: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let bgAccent: Color
    let bgAccentRed: Color
    let bgCard: Color
    let bgInput: Color
    let bgOverlay: Color

    // Text
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverse: Color

    // Borders
    let border: Color
    let borderSecondary: Color
    let borderAccent: Color

    // Brand
    let accent: Color
    let accentDark: Color

    // States
    let success: Color
    let error: Color
    let info: Color
    let bgInfo: Color

    // UI chrome
    let tabBarBorder: Color
    let divider: Color
    let iconDefault: Color
    let iconSecondary: Color
    let searchBg: Color

    // Progress bar
    let progressFilled: Color
    let progressEmpty: Color
    let bgProgress: Color
    let textProgress: Color

    // Tab bar
    let tabBar: Color

    // Auth screen
    let loginBg: Color
    let oauthBg: Color
    let oauthBorder: Color
    let oauthText: Color
}

// MARK: - Light & Dark Instances
// Semantic tokens mapped from theme.css OKLCH values → closest named palette step

extension AppColors {

    // Light: --background ≈ sand-50, --card = white, --primary = crimson-500
    static let light = AppColors(
        bg:              Palette.Sand.s50,        // oklch(0.9875 0.0045 314.8) ≈ #faf9f7
        bgSecondary:     Palette.Sand.s100,       // oklch(0.967 0.0106 316.5) ≈ #f5f5f4
        bgTertiary:      Palette.Sand.s200,       // #e7e5e4
        bgAccent:        Palette.Crimson.c50,     // lightest crimson tint
        bgAccentRed:     Palette.Crimson.c50,
        bgCard:          .white,                  // --card = oklch(1 0 0)
        bgInput:         .white,                  // --input = white
        bgOverlay:       Color.black.opacity(0.5),

        text:            Palette.Sand.s900,       // oklch(0.2277 0.0105 312) ≈ #24211e
        textSecondary:   Palette.Sand.s500,       // muted-foreground ≈ #79716b
        textTertiary:    Palette.Sand.s400,       // #a6a09b
        textInverse:     Palette.Sand.s50,

        border:          Palette.Sand.s200,       // --border oklch(0.9419 0.016 310) ≈ #e7e5e4
        borderSecondary: Palette.Sand.s300,       // #d6d3d1
        borderAccent:    Palette.Crimson.c100,    // subtle crimson border

        accent:          Palette.Crimson.c500,    // --primary = crimson-500 #ce1111
        accentDark:      Palette.Crimson.c600,    // #a50e0e

        success:         Palette.Green.g600,      // #16a34a
        error:           Palette.Crimson.c500,    // --destructive ≈ crimson
        info:            Palette.Mint.m500,
        bgInfo:          Palette.Mint.m50,

        tabBarBorder:    Palette.Sand.s200,
        divider:         Palette.Sand.s200,
        iconDefault:     Palette.Sand.s700,
        iconSecondary:   Palette.Sand.s500,
        searchBg:        Palette.Sand.s100,

        progressFilled:  Palette.Green.g500,      // #22c55e (bright green, matches RN)
        progressEmpty:   Palette.Green.g100,      // #dcfce7 (light mint-green, matches RN)
        bgProgress:      Palette.Green.g100,
        textProgress:    Palette.Green.g700,

        tabBar:          .white,

        loginBg:         Palette.Sand.s100,         // #f1efea (warm background behind login card)
        oauthBg:         Palette.Sand.s50,
        oauthBorder:     Palette.Sand.s200,
        oauthText:       Palette.Sand.s600
    )

    // Dark: --background = oklch(0.1836 ...) ≈ sand-950, --primary = crimson-400
    static let dark = AppColors(
        bg:              Palette.Sand.s950,       // oklch(0.1836 0.0111 311.9) ≈ #14110f
        bgSecondary:     Palette.Sand.s900,       // --secondary dark ≈ #24211e
        bgTertiary:      Palette.Sand.s800,       // #312c2b
        bgAccent:        Palette.Crimson.c950,
        bgAccentRed:     Palette.Crimson.c950,
        bgCard:          Palette.Sand.s900,       // --card dark = same as bg; use s900 for contrast
        bgInput:         Palette.Sand.s800,       // --input dark ≈ secondary
        bgOverlay:       Color.black.opacity(0.7),

        text:            Palette.Sand.s100,       // --foreground dark ≈ #f5f5f4
        textSecondary:   Palette.Sand.s400,       // muted-foreground dark ≈ #a6a09b
        textTertiary:    Palette.Sand.s500,       // #79716b
        textInverse:     Palette.Sand.s900,

        border:          Palette.Sand.s700,       // --border dark oklch(0.2941 0.0175) ≈ #44403b
        borderSecondary: Palette.Sand.s800,       // #312c2b
        borderAccent:    Palette.Crimson.c900,

        accent:          Palette.Crimson.c400,    // --primary dark = crimson-400 #d84141
        accentDark:      Palette.Crimson.c500,

        success:         Palette.Green.g500,
        error:           Palette.Crimson.c400,
        info:            Palette.Mint.m400,
        bgInfo:          Palette.Mint.m950,

        tabBarBorder:    Palette.Sand.s800,
        divider:         Palette.Sand.s800,
        iconDefault:     Palette.Sand.s300,
        iconSecondary:   Palette.Sand.s400,
        searchBg:        Palette.Sand.s800,

        progressFilled:  Palette.Green.g500,
        progressEmpty:   Palette.Green.g900,      // dark green empty on dark bg
        bgProgress:      Palette.Green.g900,
        textProgress:    Palette.Green.g500,

        tabBar:          Palette.Sand.s950,

        loginBg:         Palette.Sand.s950,
        oauthBg:         Palette.Sand.s900,
        oauthBorder:     Palette.Sand.s700,
        oauthText:       Palette.Sand.s300
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
        static func regular(_ size: CGFloat) -> Font  { .custom("StackSansNotch-Regular",  size: size) }
        static func medium(_ size: CGFloat) -> Font   { .custom("StackSansNotch-Medium",   size: size) }
        static func semibold(_ size: CGFloat) -> Font { .custom("StackSansNotch-SemiBold", size: size) }
        static func bold(_ size: CGFloat) -> Font     { .custom("StackSansNotch-Bold",     size: size) }
    }
    enum Body {
        static func regular(_ size: CGFloat) -> Font  { .custom("Inter-Regular",  size: size) }
        static func medium(_ size: CGFloat) -> Font   { .custom("Inter-Medium",   size: size) }
        static func semibold(_ size: CGFloat) -> Font { .custom("Inter-SemiBold", size: size) }
        static func bold(_ size: CGFloat) -> Font     { .custom("Inter-Bold",     size: size) }
    }
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
