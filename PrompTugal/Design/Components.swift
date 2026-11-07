import SwiftUI

// MARK: - Cards

/// The basic surface: a rounded card on the paper background.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Space.radius, style: .continuous)
                .strokeBorder(Palette.rule.opacity(0.7), lineWidth: 0.5))
    }
}

/// A card with a small uppercase kicker, a serif title and an optional trailing accessory.
struct TitledCard<Content: View, Accessory: View>: View {
    let kicker: String?
    let title: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(_ title: String, kicker: String? = nil,
         @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.kicker = kicker
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
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
    init(_ title: String, kicker: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, kicker: kicker, accessory: { EmptyView() }, content: content)
    }
}

/// The small red uppercase label the website uses above headlines.
struct Kicker: View {
    let text: String
    var color: Color = Palette.red
    init(_ text: String, color: Color = Palette.red) { self.text = text; self.color = color }

    var body: some View {
        Text(text.uppercased())
            .font(Typo.kicker)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// A screen header: kicker, serif display title and a one-line summary.
struct ScreenHeader: View {
    let kicker: String
    let title: String
    var summary: String?

    var body: some View {
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
struct StatTile: View {
    enum Tone { case neutral, good, warn, bad }

    let label: String
    let value: String
    var detail: String?
    var tone: Tone = .neutral
    var trend: [Double] = []

    private var color: Color {
        switch tone {
        case .neutral: Palette.ink
        case .good: Palette.green
        case .warn: Palette.amber
        case .bad: Palette.red
        }
    }

    var body: some View {
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
struct StatGrid<Content: View>: View {
    var minimum: CGFloat = 140
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: Space.m)], spacing: Space.m) {
            content
        }
    }
}

/// A tiny line chart drawn with a Path, for tiles and rows.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Palette.red

    var body: some View {
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
struct CountPill: View {
    let count: Int
    let label: String
    var color: Color = Palette.red

    var body: some View {
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

enum SurfaceKind: Hashable, Sendable {
    case native
    case web(URL)
    case hybrid

    var label: String {
        switch self {
        case .native: "Native"
        case .web: "Web"
        case .hybrid: "Hybrid"
        }
    }

    var symbol: String {
        switch self {
        case .native: "swift"
        case .web: "globe"
        case .hybrid: "square.split.2x1"
        }
    }

    var color: Color {
        switch self {
        case .native: Palette.green
        case .web: Palette.blue
        case .hybrid: Palette.amber
        }
    }
}

/// The small "native / web / hybrid" badge. Shown on every screen in debug mode.
struct KindBadge: View {
    let kind: SurfaceKind

    var body: some View {
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
    func surfaceKind(_ kind: SurfaceKind) -> some View { modifier(KindBadgeModifier(kind: kind)) }
}

private struct KindBadgeModifier: ViewModifier {
    let kind: SurfaceKind
    @AppStorage(DebugMode.key) private var debug = false

    func body(content: Content) -> some View {
        content.toolbar {
            if debug {
                ToolbarItem(placement: .topBarTrailing) { KindBadge(kind: kind) }
            }
        }
    }
}

/// The one switch for debug mode, shared by Settings, the shell and the badges.
enum DebugMode {
    static let key = "debug.enabled"
}

// MARK: - Load states

/// What a screen knows about its data.
enum LoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// "Updated 4 min ago", in amber once the data is older than `staleAfter`.
struct FreshnessLabel: View {
    let updated: Date?
    var staleAfter: TimeInterval = 30 * 60
    var failed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let updated {
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
                Label("Not loaded", systemImage: "wifi.slash").font(.caption).foregroundStyle(Palette.amber)
            }
        }
    }
}

/// The standard empty, loading and error states, so every screen says the same thing the same way.
struct StateView: View {
    let phase: LoadPhase
    let hasData: Bool
    var title = "data"
    var retry: (() -> Void)?

    var body: some View {
        if !hasData {
            switch phase {
            case .idle, .loading:
                VStack(spacing: Space.m) {
                    ProgressView()
                    Text("Loading \(title)…").font(.footnote).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            case .failed(let message):
                ContentUnavailableView {
                    Label("\(title.capitalized) unavailable", systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    if let retry { Button("Try again", action: retry).buttonStyle(.borderedProminent) }
                }
            case .loaded:
                ContentUnavailableView("Nothing here yet", systemImage: "tray",
                                       description: Text("The \(title) is empty."))
            }
        }
    }
}

/// A plain note that says what the app cannot show, and why. Used for honest gaps.
struct GapNote: View {
    let title: String
    let text: String

    var body: some View {
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
struct Page<Content: View>: View {
    var maxWidth: CGFloat = 1200
    @ViewBuilder var content: Content

    var body: some View {
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
struct Columns<Leading: View, Trailing: View>: View {
    @Environment(\.horizontalSizeClass) private var width
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
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
enum Bytes {
    static func format(_ count: Int) -> String {
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
