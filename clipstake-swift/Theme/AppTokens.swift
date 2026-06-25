import SwiftUI

// MARK: - Spacing (4pt grid)

func space(_ n: CGFloat) -> CGFloat { n * 4 }

// MARK: - Radius

enum Radius {
    static let sm:   CGFloat = 6
    static let md:   CGFloat = 10
    static let lg:   CGFloat = 12
    static let xl:   CGFloat = 16
    static let xl2:  CGFloat = 20
    static let xl3:  CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Shadows

struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension AppShadow {
    static let card = AppShadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    static let lg   = AppShadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
}

// MARK: - Animation Presets

extension Animation {
    static let tabSlide     = Animation.spring(response: 0.35, dampingFraction: 0.78)
    static let sheetOpen    = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let buttonPress  = Animation.spring(response: 0.2,  dampingFraction: 0.6)
    static let cardAppear   = Animation.spring(response: 0.4)
    static let fadeOut      = Animation.easeOut(duration: 0.2)
    static let conditional  = Animation.spring(response: 0.3,  dampingFraction: 0.75)
}

// MARK: - Constants

enum Layout {
    static let tabBarMaxWidth: CGFloat = 560
    static let tabSquareSize:  CGFloat = 44
    static let tabCount:       Int     = 5
    static let tabBarPadX:     CGFloat = 16
    static let iPadMaxWidth:   CGFloat = 560
    static let pagePadX:       CGFloat = 16
}
