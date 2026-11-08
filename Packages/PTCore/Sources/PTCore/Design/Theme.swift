import SwiftUI
import UIKit

/// The PrompTugal palette, from the app icon and the AccentColor asset.
/// Ink, red and green on paper. Every colour has a light and a dark value,
/// and the dark values are the website's (`website/site.css`).
public enum Palette {
    public static let paper = Color(light: 0xF5F1EA, dark: 0x14161B)
    public static let paper2 = Color(light: 0xEBE5DA, dark: 0x1C1F25)
    public static let card = Color(light: 0xFFFDF9, dark: 0x1F2229)
    public static let ink = Color(light: 0x111318, dark: 0xECE7DE)
    public static let muted = Color(light: 0x555A63, dark: 0xA7ABB3)
    public static let rule = Color(light: 0xD6CFC2, dark: 0x343842)
    public static let red = Color(light: 0xAD222B, dark: 0xFF868A)
    public static let green = Color(light: 0x0B6B1E, dark: 0x6FCF7F)
    /// Amber for "stale" and "partial". Not in the icon; chosen to pass 4.5:1 on card in both themes.
    public static let amber = Color(light: 0x8A5A00, dark: 0xF2C14E)
    /// Blue for "web" badges and links to the web twin.
    public static let blue = Color(light: 0x1F4FA3, dark: 0x8FB4FF)

    /// Categorical colours for charts, in a fixed order, so a series keeps its colour across screens.
    public static let series: [Color] = [red, green, blue, amber,
                                  Color(light: 0x6B3FA0, dark: 0xC5A3FF),
                                  Color(light: 0x0F6E75, dark: 0x6FD6DE),
                                  Color(light: 0x7A4A2B, dark: 0xD9A27A),
                                  muted]

    public static func series(_ index: Int) -> Color { series[abs(index) % series.count] }

    /// A stable colour for any string (an agent, a person, a type).
    public static func stable(_ key: String) -> Color {
        var hash: UInt32 = 2166136261
        for byte in key.utf8 { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return series(Int(hash % UInt32(series.count)))
    }
}

extension Color {
    /// A colour that follows the system appearance. Values are 0xRRGGBB.
    public init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// A colour from a CSS hex string such as "#1e7b4f". Falls back to muted.
    public init(hex: String?) {
        guard let hex, let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) else {
            self = Palette.muted
            return
        }
        self.init(uiColor: UIColor(rgb: value))
    }
}

extension UIColor {
    public convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

/// Type: serif for headlines (like the brand), SF for interface text, SF Mono for data.
/// All styles are text styles, so they follow Dynamic Type.
public enum Typo {
    public static let display = Font.system(.largeTitle, design: .serif, weight: .bold)
    public static let title = Font.system(.title2, design: .serif, weight: .bold)
    public static let headline = Font.system(.headline, design: .serif, weight: .semibold)
    public static let kicker = Font.caption.weight(.semibold)
    public static let body = Font.body
    public static let meta = Font.footnote
    public static let data = Font.system(.footnote, design: .monospaced)
    public static let dataSmall = Font.system(.caption2, design: .monospaced)
    public static let number = Font.system(.title, design: .rounded, weight: .semibold).monospacedDigit()
}

/// Spacing on a 4-point grid.
public enum Space {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let radius: CGFloat = 14
    public static let readable: CGFloat = 680
}
