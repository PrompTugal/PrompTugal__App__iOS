import SwiftUI

// MARK: - Cards

/// The basic surface: a rounded card on the paper background.
public struct Card<Content: View>: View {
    public var padding: CGFloat = Space.l
    @ViewBuilder public var content: Content

    public init(padding: CGFloat = Space.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Space.radius, style: .continuous)
                .strokeBorder(Palette.rule.opacity(0.7), lineWidth: 0.5))
    }
}

/// A card with a small uppercase kicker, a serif title and an optional trailing accessory.
public struct TitledCard<Content: View, Accessory: View>: View {
    public let kicker: String?
    public let title: String
    @ViewBuilder public var accessory: Accessory
    @ViewBuilder public var content: Content

    public init(_ title: String, kicker: String? = nil,
         @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.kicker = kicker
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if let kicker { Kicker(kicker) }
                    Text(title).font(Typo.headline).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: Space.s)
                accessory
            }
            content
        }
    }
}

extension TitledCard where Accessory == EmptyView {
    public init(_ title: String, kicker: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, kicker: kicker, accessory: { EmptyView() }, content: content)
    }
}

/// The small red uppercase label the website uses above headlines.
public struct Kicker: View {
    public let text: String
    public var color: Color = Palette.red
    public init(_ text: String, color: Color = Palette.red) { self.text = text; self.color = color }

    public var body: some View {
        Text(text.uppercased())
            .font(Typo.kicker)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// A screen header: kicker, serif display title and a one-line summary.
public struct ScreenHeader: View {
    public let kicker: String
    public let title: String
    public var summary: String?

    public init(kicker: String, title: String, summary: String? = nil) {
        self.kicker = kicker
        self.title = title
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Kicker(kicker)
            Text(title).font(Typo.display).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if let summary {
                Text(summary).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat tiles

/// One number with a label, an optional trend line and a tone.
public struct StatTile: View {
    public enum Tone { case neutral, good, warn, bad }

    public let label: String
    public let value: String
    public var detail: String?
    public var tone: Tone = .neutral
    public var trend: [Double] = []

    public init(label: String, value: String, detail: String? = nil, tone: Tone = .neutral, trend: [Double] = []) {
        self.label = label
        self.value = value
        self.detail = detail
        self.tone = tone
        self.trend = trend
    }

    private var color: Color {
        switch tone {
        case .neutral: Palette.ink
        case .good: Palette.green
        case .warn: Palette.amber
        case .bad: Palette.red
        }
    }

    public var body: some View {
        Card(padding: Space.m) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(Palette.muted).lineLimit(2)
            Text(value).font(Typo.number).foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
            if trend.count > 1 {
                Sparkline(values: trend, color: color).frame(height: 22)
            }
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(Palette.muted).lineLimit(2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)\(detail.map { ", \($0)" } ?? "")")
    }
}

/// A row of stat tiles that wraps on narrow widths.
public struct StatGrid<Content: View>: View {
    public var minimum: CGFloat = 140
    @ViewBuilder public var content: Content

    public init(minimum: CGFloat = 140, @ViewBuilder content: () -> Content) {
        self.minimum = minimum
        self.content = content()
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: Space.m)], spacing: Space.m) {
            content
        }
    }
}

/// A tiny line chart drawn with a Path, for tiles and rows.
public struct Sparkline: View {
    public let values: [Double]
    public var color: Color = Palette.red

    public init(values: [Double], color: Color = Palette.red) {
        self.values = values
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 1, 1)
            let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
            Path { path in
                for (index, value) in values.enumerated() {
                    let point = CGPoint(x: CGFloat(index) * step,
                                        y: geo.size.height * (1 - CGFloat(value / maxValue)))
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// A count in a capsule, used for "only you", "decide" and "overdue".
public struct CountPill: View {
    public let count: Int
    public let label: String
    public var color: Color = Palette.red

    public init(count: Int, label: String, color: Color = Palette.red) {
        self.count = count
        self.label = label
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 3) {
            Text("\(count)").font(.caption.weight(.bold).monospacedDigit())
            Text(label).font(.caption2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(count > 0 ? color : Palette.muted)
        .background((count > 0 ? color : Palette.muted).opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Native / web / hybrid badge

public enum SurfaceKind: Hashable, Sendable {
    case native
    case web(URL)
    case hybrid

    public var label: String {
        switch self {
        case .native: "Native"
        case .web: "Web"
        case .hybrid: "Hybrid"
        }
    }

    public var symbol: String {
        switch self {
        case .native: "swift"
        case .web: "globe"
        case .hybrid: "square.split.2x1"
        }
    }

    public var color: Color {
        switch self {
        case .native: Palette.green
        case .web: Palette.blue
        case .hybrid: Palette.amber
        }
    }
}

/// The small "native / web / hybrid" badge. Shown on every screen in debug mode.
public struct KindBadge: View {
    public let kind: SurfaceKind

    public init(kind: SurfaceKind) {
        self.kind = kind
    }

    public var body: some View {
        Label(kind.label, systemImage: kind.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(kind.color)
            .background(kind.color.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(kind.color.opacity(0.4), lineWidth: 0.5))
            .accessibilityLabel("\(kind.label) screen")
    }
}

extension View {
    /// Adds the kind badge to the toolbar when debug mode is on.
    public func surfaceKind(_ kind: SurfaceKind) -> some View { modifier(KindBadgeModifier(kind: kind)) }
}

private struct KindBadgeModifier: ViewModifier {
    let kind: SurfaceKind
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn

    func body(content: Content) -> some View {
        content.toolbar {
            if debug {
                ToolbarItem(placement: .topBarTrailing) { KindBadge(kind: kind) }
            }
        }
    }
}

/// The one switch for debug mode, shared by Settings, the shell and the badges.
public enum DebugMode {
    public static let key = "debug.enabled"
    /// On in debug builds, where the team wants to see the app's working. Off in release builds:
    /// App Review and attendees see no debug panels unless they turn them on in Settings.
    #if DEBUG
    public static let defaultOn = true
    #else
    public static let defaultOn = false
    #endif
}

// MARK: - Previews on both devices

/// Every screen is previewed at iPhone and iPad sizes, with the size class each really has.
public enum PreviewDevice {
    public static let phone = CGSize(width: 393, height: 852)
    public static let pad = CGSize(width: 1180, height: 820)
}

extension View {
    /// The compact (iPhone) layout of a screen, for previews.
    public func phonePreview() -> some View {
        environment(\.horizontalSizeClass, .compact).frame(width: PreviewDevice.phone.width, height: PreviewDevice.phone.height)
    }

    /// The regular (iPad landscape) layout of a screen, for previews.
    public func padPreview() -> some View {
        environment(\.horizontalSizeClass, .regular).frame(width: PreviewDevice.pad.width, height: PreviewDevice.pad.height)
    }
}

// MARK: - Load states

/// What a screen knows about its data.
public enum LoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// "Updated 4 min ago", in amber once the data is older than `staleAfter`.
public struct FreshnessLabel: View {
    public let updated: Date?
    public var staleAfter: TimeInterval = 30 * 60

    public var failed = false

    public init(updated: Date?, staleAfter: TimeInterval = 30 * 60, failed: Bool = false) {
        self.updated = updated
        self.staleAfter = staleAfter
        self.failed = failed
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let raw = updated {
                // A time stamp in the future (a clock ahead, or sample data) reads as now.
                let updated = min(raw, context.date)
                let stale = context.date.timeIntervalSince(updated) > staleAfter
                Label {
                    Text(failed ? "Offline · updated " : "Updated ")
                        + Text(updated, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                } icon: {
                    Image(systemName: failed ? "wifi.slash" : (stale ? "clock.badge.exclamationmark" : "clock"))
                }
                .font(.caption)
                .foregroundStyle(failed || stale ? Palette.amber : Palette.muted)
            } else if failed {
                Label(String(localized: "Not loaded", bundle: .module), systemImage: "wifi.slash").font(.caption).foregroundStyle(Palette.amber)
            }
        }
    }
}

/// The standard empty, loading and error states, so every screen says the same thing the same way.
public struct StateView: View {
    public let phase: LoadPhase
    public let hasData: Bool
    public var title = "data"
    public var retry: (() -> Void)?

    public init(phase: LoadPhase, hasData: Bool, title: String = "data", retry: (() -> Void)? = nil) {
        self.phase = phase
        self.hasData = hasData
        self.title = title
        self.retry = retry
    }

    public var body: some View {
        if !hasData {
            switch phase {
            case .idle, .loading:
                VStack(spacing: Space.m) {
                    ProgressView()
                    Text(String(localized: "Loading \(title)…", bundle: .module)).font(.footnote).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            case .failed(let message):
                ContentUnavailableView {
                    Label(String(localized: "\(title.capitalized) unavailable", bundle: .module), systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    if let retry { Button(String(localized: "Try again", bundle: .module), action: retry).buttonStyle(.borderedProminent) }
                }
            case .loaded:
                ContentUnavailableView(String(localized: "Nothing here yet", bundle: .module), systemImage: "tray",
                                       description: Text(String(localized: "The \(title) is empty.", bundle: .module)))
            }
        }
    }
}

/// A plain note that says what the app cannot show, and why. Used for honest gaps.
public struct GapNote: View {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: "eye.slash").foregroundStyle(Palette.amber).font(.title3)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Layout helpers

/// The paper-coloured scroll page every dashboard uses.
public struct Page<Content: View>: View {
    public var maxWidth: CGFloat = 1200
    @ViewBuilder public var content: Content

    public init(maxWidth: CGFloat = 1200, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) { content }
                .padding(Space.l)
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .background(Palette.paper.ignoresSafeArea())
    }
}

/// Two columns on a wide screen, one on a narrow one.
public struct Columns<Leading: View, Trailing: View>: View {
    @Environment(\.horizontalSizeClass) private var width
    @ViewBuilder public var leading: Leading
    @ViewBuilder public var trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        if width == .regular {
            HStack(alignment: .top, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.l) { leading }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Space.l) { trailing }.frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: Space.l) {
                leading
                trailing
            }
        }
    }
}

/// Formats a byte count the same way everywhere.
public enum Bytes {
    public static func format(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

#Preview("Design system") {
    Page {
        ScreenHeader(kicker: "Design", title: "PrompTugal", summary: "Ink, red and green on paper.")
        StatGrid {
            StatTile(label: "Only you", value: "4", tone: .bad, trend: [1, 3, 2, 4, 4])
            StatTile(label: "Decide", value: "23", tone: .warn)
            StatTile(label: "Agents running", value: "26", tone: .good)
        }
        HStack { KindBadge(kind: .native); KindBadge(kind: .hybrid); KindBadge(kind: .web(FeedClient.site)) }
        FreshnessLabel(updated: .now.addingTimeInterval(-240))
        FreshnessLabel(updated: .now.addingTimeInterval(-7200))
        GapNote(title: "Traffic is sealed", text: "Page views are written to a write-only vault lane.")
        StateView(phase: .failed("No connection."), hasData: false, title: "team")
    }
}
