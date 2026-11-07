import SwiftUI
import UIKit

/// The PrompTugal palette, from the app icon and the AccentColor asset.
/// Ink, red and green on paper. Every colour has a light and a dark value,
/// and the dark values are the website's (`website/site.css`).
enum Palette {
    static let paper = Color(light: 0xF5F1EA, dark: 0x14161B)
    static let paper2 = Color(light: 0xEBE5DA, dark: 0x1C1F25)
    static let card = Color(light: 0xFFFDF9, dark: 0x1F2229)
    static let ink = Color(light: 0x111318, dark: 0xECE7DE)
    static let muted = Color(light: 0x555A63, dark: 0xA7ABB3)
    static let rule = Color(light: 0xD6CFC2, dark: 0x343842)
    static let red = Color(light: 0xAD222B, dark: 0xFF868A)
    static let green = Color(light: 0x0B6B1E, dark: 0x6FCF7F)
    /// Amber for "stale" and "partial". Not in the icon; chosen to pass 4.5:1 on card in both themes.
    static let amber = Color(light: 0x8A5A00, dark: 0xF2C14E)
    /// Blue for "web" badges and links to the web twin.
    static let blue = Color(light: 0x1F4FA3, dark: 0x8FB4FF)

    /// Categorical colours for charts, in a fixed order, so a series keeps its colour across screens.
    static let series: [Color] = [red, green, blue, amber,
                                  Color(light: 0x6B3FA0, dark: 0xC5A3FF),
                                  Color(light: 0x0F6E75, dark: 0x6FD6DE),
                                  Color(light: 0x7A4A2B, dark: 0xD9A27A),
                                  muted]

    static func series(_ index: Int) -> Color { series[abs(index) % series.count] }

    /// A stable colour for any string (an agent, a person, a type).
    static func stable(_ key: String) -> Color {
        var hash: UInt32 = 2166136261
        for byte in key.utf8 { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return series(Int(hash % UInt32(series.count)))
    }
}

extension Color {
    /// A colour that follows the system appearance. Values are 0xRRGGBB.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// A colour from a CSS hex string such as "#1e7b4f". Falls back to muted.
    init(hex: String?) {
        guard let hex, let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) else {
            self = Palette.muted
            return
        }
        self.init(uiColor: UIColor(rgb: value))
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

/// Type: serif for headlines (like the brand), SF for interface text, SF Mono for data.
/// All styles are text styles, so they follow Dynamic Type.
enum Typo {
    static let display = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let title = Font.system(.title2, design: .serif, weight: .bold)
    static let headline = Font.system(.headline, design: .serif, weight: .semibold)
    static let kicker = Font.caption.weight(.semibold)
    static let body = Font.body
    static let meta = Font.footnote
    static let data = Font.system(.footnote, design: .monospaced)
    static let dataSmall = Font.system(.caption2, design: .monospaced)
    static let number = Font.system(.title, design: .rounded, weight: .semibold).monospacedDigit()
}

/// Spacing on a 4-point grid.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let radius: CGFloat = 14
    static let readable: CGFloat = 680
}
