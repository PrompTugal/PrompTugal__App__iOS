import SwiftUI

// One way to say where a screen's data came from, and one way to mark what is simulated.
// Design direction: briefs/2026-11-25__c-ios/design/direction.md ("Provenance: honest but calm").
// Additive: nothing changes until a screen uses these.

/// Where a screen's (or a block's) data came from.
public enum SourceState: Equatable, Sendable {
    /// Read from the source just now (or at the given time this session).
    case live(Date)
    /// The last copy this device saved, read at the given time if known.
    case saved(Date?)
    /// The copy built into the app, read on the given day (for example "21 Nov 2026").
    case builtIn(String)
    /// Read just now, but the data itself carries an older date (for example "21 Nov"): the feed has not moved.
    /// Same rule as PTPlaces' `PlacesOrigin.dated`: data older than a day never says "Live".
    case dated(String)
    /// Nothing to show yet.
    case notLoaded

    public var isLive: Bool { if case .live = self { true } else { false } }

    /// The one word for the state, the same on every screen.
    public var title: String {
        switch self {
        case .live: String(localized: "Live", bundle: .module)
        case .saved: String(localized: "Saved copy", bundle: .module)
        case .builtIn: String(localized: "Built-in", bundle: .module)
        case .dated: String(localized: "Data dated", bundle: .module)
        case .notLoaded: String(localized: "Not loaded", bundle: .module)
        }
    }

    var symbol: String {
        switch self {
        case .live: "circle.fill"
        case .saved: "arrow.down.circle"
        case .builtIn: "shippingbox"
        case .dated: "calendar"
        case .notLoaded: "wifi.slash"
        }
    }

    var tint: Color { isLive ? Palette.ok : Palette.warn }

    /// A live state whose read time is older than `staleAfter` is shown as a saved copy: never let old data say "Live".
    public func honest(staleAfter: TimeInterval = 24 * 60 * 60, now: Date = .now) -> SourceState {
        if case .live(let date) = self, now.timeIntervalSince(date) > staleAfter { return .saved(date) }
        return self
    }
}

/// "Live · promptugal.news · 2 min ago", "Saved copy · read 24 Nov, 18:40", "Built-in · read 21 Nov",
/// "Data dated 21 Nov · data.promptugal.news".
/// Only the icon carries colour; the text stays muted, so an honest note never reads as an alarm.
public struct SourceStamp: View {
    public let state: SourceState
    /// The source's short name, such as "promptugal.news" or "IPMA". Shown for live data.
    public var source: String?
    public var loading = false
    public var retry: (() -> Void)?

    public init(_ state: SourceState, source: String? = nil, loading: Bool = false, retry: (() -> Void)? = nil) {
        self.state = state
        self.source = source
        self.loading = loading
        self.retry = retry
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let shown = state.honest(now: context.date)
            HStack(spacing: 6) {
                if loading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: shown.symbol)
                        .font(shown.isLive ? .system(size: 7) : .caption)
                        .foregroundStyle(shown.tint)
                        .accessibilityHidden(true)
                }
                Text(line(shown, now: context.date))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                if case .notLoaded = shown, let retry {
                    Button(String(localized: "Try again", bundle: .module), action: retry)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.brand)
                        .buttonStyle(.plain)
                }
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spoken(shown, now: context.date))
        }
    }

    private func line(_ state: SourceState, now: Date) -> String {
        var parts = [state.title]
        switch state {
        case .live(let date):
            if let source { parts.append(source) }
            parts.append(Self.when(date, now: now))
        case .saved(let date?):
            parts.append(String(localized: "read \(Self.when(date, now: now))", bundle: .module))
        case .builtIn(let day):
            if !day.isEmpty { parts.append(String(localized: "read \(day)", bundle: .module)) }
        case .dated(let day):
            parts[0] = String(localized: "Data dated \(day)", bundle: .module)
            if let source { parts.append(source) }
        case .saved(nil), .notLoaded:
            break
        }
        return parts.joined(separator: " · ")
    }

    private func spoken(_ state: SourceState, now: Date) -> String {
        line(state, now: now).replacingOccurrences(of: " · ", with: ", ")
    }

    /// Relative under a day ("2 min ago"), else the date and time ("24 Nov, 18:40").
    static func when(_ date: Date, now: Date) -> String {
        let shown = min(date, now)
        if now.timeIntervalSince(shown) < 24 * 60 * 60 {
            return shown.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        }
        return shown.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

/// The "Simulated" tag: an outlined, muted capsule with a replay icon. It marks a replay or a simulation, calmly
/// and always: no setting hides it. Put it top-trailing on the simulated block, or use `.simulatedBlock()`.
public struct SimulatedTag: View {
    public init() {}

    public var body: some View {
        Label(String(localized: "Simulated", bundle: .module), systemImage: "play.rectangle")
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(Palette.muted)
            .overlay(Capsule().strokeBorder(Palette.muted.opacity(0.6), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Simulated: a replay, not live data", bundle: .module))
    }
}

extension View {
    /// Marks a whole block as simulated: a dashed rule-coloured border around it and the `SimulatedTag` at its
    /// top-trailing corner, so the tag never scrolls away from what it describes.
    public func simulatedBlock(cornerRadius: CGFloat = Space.radius) -> some View {
        self
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Palette.rule, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .overlay(alignment: .topTrailing) { SimulatedTag().padding(Space.s) }
    }
}

#Preview("Source stamps") {
    Page(maxWidth: Space.readable) {
        SourceStamp(.live(.now.addingTimeInterval(-120)), source: "promptugal.news")
        SourceStamp(.live(.now.addingTimeInterval(-3 * 24 * 3600)), source: "IPMA")
        SourceStamp(.saved(.now.addingTimeInterval(-26 * 3600)))
        SourceStamp(.builtIn("21 Nov 2026"))
        SourceStamp(.dated("21 Nov"), source: "data.promptugal.news")
        SourceStamp(.notLoaded) {}
        Card {
            Text("The city newsroom, replayed").font(Typo.headline)
            Text("Agents hand stories to each other.").font(.footnote).foregroundStyle(Palette.muted)
        }
        .simulatedBlock()
    }
}
