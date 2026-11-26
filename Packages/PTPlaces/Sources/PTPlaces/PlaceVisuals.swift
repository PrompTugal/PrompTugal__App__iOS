import MapKit
import PTCore
import SwiftUI
import UIKit

// The visual parts of the places magazine: covers in each town's own accent, satellite imagery from MapKit
// (real pictures of the place at no asset cost), the PrompTugal test as dots, big numbers, the agents' faces.

extension Color {
    /// "#9A3412" or "9A3412"; nil for anything else.
    public init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

enum PlaceTheme {
    /// The town's accent from its file, else a stable colour from its id.
    /// In light mode the colour is darkened to at most 45% lightness, so text and pins in it read on paper and on
    /// the map's pale land (design review D); dark mode keeps it as the town wrote it.
    static func accent(_ file: PlaceFile?, id: String) -> Color {
        var base = Palette.stable(id)
        if let hex = file?.look?.accent, let color = Color(hexString: hex) { base = color }
        let resolved = UIColor(base)
        return Color(uiColor: UIColor { traits in
            let color = resolved.resolvedColor(with: traits)
            guard traits.userInterfaceStyle != .dark else { return color }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }
            let c = clamp(red: Double(r), green: Double(g), blue: Double(b))
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: a)
        })
    }

    /// The same hue and saturation with HSL lightness at most `maxLightness`.
    static func clamp(red: Double, green: Double, blue: Double, maxLightness: Double = 0.45)
        -> (red: Double, green: Double, blue: Double) {
        let high = max(red, green, blue), low = min(red, green, blue)
        let lightness = (high + low) / 2
        guard lightness > maxLightness else { return (red, green, blue) }
        let delta = high - low
        if delta == 0 { return (maxLightness, maxLightness, maxLightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        if high == red { hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
        else if high == green { hue = (blue - red) / delta + 2 }
        else { hue = (red - green) / delta + 4 }
        hue = hue < 0 ? hue + 6 : hue
        let chroma = (1 - abs(2 * maxLightness - 1)) * min(saturation, 1)
        let x = chroma * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1))
        let m = maxLightness - chroma / 2
        let rgb: [Double]
        switch hue {
        case ..<1: rgb = [chroma, x, 0]
        case ..<2: rgb = [x, chroma, 0]
        case ..<3: rgb = [0, chroma, x]
        case ..<4: rgb = [0, x, chroma]
        case ..<5: rgb = [x, 0, chroma]
        default: rgb = [chroma, 0, x]
        }
        return (rgb[0] + m, rgb[1] + m, rgb[2] + m)
    }

    static func coordinate(_ place: PlaceSummary) -> CLLocationCoordinate2D? {
        guard let at = place.at, at.count == 2 else { return nil }
        return CLLocationCoordinate2D(latitude: at[1], longitude: at[0])
    }

    /// How far the camera sits above a place: the country far, the region wide, a town close.
    static func distance(_ place: PlaceSummary) -> CLLocationDistance {
        switch place.kind {
        case "country": 1_400_000
        case "region": 260_000
        case "city": 6_000
        default: 9_000
        }
    }

    static func kindLabel(_ kind: String) -> String {
        switch kind {
        case "country": String(localized: "Country", bundle: .module)
        case "region": String(localized: "Region", bundle: .module)
        case "city": String(localized: "City", bundle: .module)
        default: String(localized: "Municipality", bundle: .module)
        }
    }
}

/// A real aerial picture of the place: MapKit's satellite imagery with a tilted camera, not interactive.
struct SatelliteView: View {
    let place: PlaceSummary
    var pitch: Double = 55
    var heading: Double = 20
    var interactive = false

    var body: some View {
        if let coordinate = PlaceTheme.coordinate(place) {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: PlaceTheme.distance(place),
                                                   heading: heading, pitch: place.kind == "country" ? 0 : pitch)),
                interactionModes: interactive ? .all : [])
                .mapStyle(.imagery(elevation: .realistic))
                .mapControlVisibility(.hidden)
                .allowsHitTesting(interactive)
        } else {
            Rectangle().fill(Palette.paper2)
        }
    }
}

/// A painted cover in the town's accent, for tiles where many live maps would be too heavy.
struct AccentCover: View {
    let accent: Color
    var seed: Int = 0

    var body: some View {
        let s = Float(seed % 7) / 20
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.35 + s, 0.45 + s / 2], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: [
            accent.opacity(0.95), accent.opacity(0.75), accent,
            accent.opacity(0.6), Color.white.opacity(0.35), accent.opacity(0.85),
            accent, accent.opacity(0.8), Color.black.opacity(0.55),
        ])
    }
}

/// Bottom-up dark fade so white type reads over imagery.
struct Scrim: View {
    var strength: Double = 0.75
    var body: some View {
        LinearGradient(colors: [.clear, .black.opacity(strength * 0.45), .black.opacity(strength)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The PrompTugal test at a glance: how many steps a story is from AI (0 = about AI itself).
struct StepsBadge: View {
    let steps: Int?
    var accent: Color = Palette.red

    var body: some View {
        if let steps {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i <= steps ? accent : accent.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
                Text(steps == 0 ? String(localized: "AI itself", bundle: .module)
                     : steps == 1 ? String(localized: "1 step from AI", bundle: .module) : String(localized: "\(steps) steps from AI", bundle: .module))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct StatusPill: View {
    let status: String
    var onDark = false

    var body: some View {
        let live = status == "live"
        Text(live ? String(localized: "Live", bundle: .module)
             : status == "researching" ? String(localized: "Researching", bundle: .module) : status.capitalized)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(live ? Palette.green : (onDark ? Color.white.opacity(0.22) : Palette.paper2), in: Capsule())
            .foregroundStyle(live ? .white : (onDark ? .white : Palette.muted))
    }
}

struct BigNumber: View {
    let value: Int
    let label: String
    var accent: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(accent)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// An agent's face: a round, happy face in its status colour, with its initials beneath when there is room.
struct AgentFace: View {
    let agent: ReportAgent
    var size: CGFloat = 44

    static func color(_ status: String) -> Color {
        switch status {
        case "working": Palette.green
        case "waiting": Palette.amber
        case "blocked": Palette.red
        case "done": Palette.blue
        default: Palette.muted
        }
    }

    static func symbol(_ status: String) -> String {
        switch status {
        case "working": "face.smiling.inverse"
        case "waiting": "hourglass.circle.fill"
        case "blocked": "exclamationmark.circle.fill"
        case "done": "checkmark.circle.fill"
        default: "moon.zzz.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(Palette.stable(agent.name).gradient)
            Image(systemName: "face.smiling")
                .font(.system(size: size * 0.55, weight: .regular))
                .foregroundStyle(.white)
            Image(systemName: Self.symbol(agent.status))
                .font(.system(size: size * 0.32))
                .foregroundStyle(.white, Self.color(agent.status))
                .background(Circle().fill(.white).padding(1))
                .offset(x: size * 0.34, y: size * 0.34)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("\(agent.name), \(agent.status)"))
    }
}

/// Kicker line in the magazine's style: small caps in the accent.
struct Kicker: View {
    let text: String
    var color: Color = Palette.red

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// A section head with a thick rule, newspaper style.
struct SectionHead: View {
    let title: String
    var subtitle: String?
    var accent: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(accent).frame(height: 3)
            Text(title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
        .padding(.top, Space.l)
        .accessibilityAddTraits(.isHeader)
    }
}
