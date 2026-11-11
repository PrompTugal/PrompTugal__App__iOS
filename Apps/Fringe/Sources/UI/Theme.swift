import SwiftUI
import UIKit

/// Option E colours, light and dark.
enum Palette {
    static let bg = Color(light: 0xfff7f0, dark: 0x17110e)
    static let panel = Color(light: 0xffffff, dark: 0x241a16)
    static let ink = Color(light: 0x2a1a14, dark: 0xf6ebe3)
    static let ink2 = Color(light: 0x5e4a40, dark: 0xcdb9ac)
    static let line = Color(light: 0xecd9cb, dark: 0x43332b)
    static let accent = Color(light: 0xb83a12, dark: 0xff8a5c)
    static let onAccent = Color(light: 0xffffff, dark: 0x1a0e08)
    static let teal = Color(light: 0x0d5f5f, dark: 0x5cc4c4)
    static let onTeal = Color(light: 0xffffff, dark: 0x0b1f1f)
    /// The Next card: deep teal in both modes, so its white text stays readable.
    static let nextCard = Color(light: 0x0d5f5f, dark: 0x134f4f)
    static let pill = Color(light: 0xf3e6dc, dark: 0x3a2a22)
    static let clashBg = Color(light: 0xd9eeee, dark: 0x173a3a)
    static let clashInk = Color(light: 0x0d5f5f, dark: 0x8fdada)
    static let statusBg = Color(light: 0xffe0d2, dark: 0x4a2416)
    static let statusInk = Color(light: 0x8f2c0d, dark: 0xffb08f)
    static let heading = Color(light: 0x0d5f5f, dark: 0x5cc4c4)

    /// Calendar colours. Each block also says its type in words.
    static let calendar: [Color] = ([0x1f4fa8, 0x0b6b3a, 0xb3540a, 0x6b3fa0, 0x8a5a00] as [UInt32]).map { Color(hex: $0) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                           green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255,
                           alpha: 1)
        })
    }
}

/// Rounded button in the option E style: panel, line, 44 points tall at least.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case plain, accent, teal }
    var kind: Kind = .plain
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pillLook(kind, fullWidth: fullWidth)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct PillLook: ViewModifier {
    let kind: PillButtonStyle.Kind
    var fullWidth = false

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 44, maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(kind == .plain ? Palette.line : .clear, lineWidth: 1))
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .plain: Palette.ink
        case .accent: Palette.onAccent
        case .teal: Palette.onTeal
        }
    }

    private var background: Color {
        switch kind {
        case .plain: Palette.panel
        case .accent: Palette.accent
        case .teal: Palette.teal
        }
    }
}

/// A small label: type, status or clash.
struct Pill: View {
    enum Kind { case plain, status, clash }
    let text: String
    var kind: Kind = .plain

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(kind == .status ? Palette.statusInk : kind == .clash ? Palette.clashInk : Palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(kind == .status ? Palette.statusBg : kind == .clash ? Palette.clashBg : Palette.pill,
                        in: RoundedRectangle(cornerRadius: 10))
    }
}

/// White card with a thin line.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
    func pillLook(_ kind: PillButtonStyle.Kind, fullWidth: Bool = false) -> some View {
        modifier(PillLook(kind: kind, fullWidth: fullWidth))
    }
}
