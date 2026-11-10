import SwiftUI
import PTNowNext
import WidgetKit

struct NowNextEntry: TimelineEntry {
    let date: Date
    let now: [NowNextSnapshot.Item]
    let next: [NowNextSnapshot.Item]
    /// nil when the app has not written a snapshot yet.
    let updatedAt: Date?

    static func make(from snapshot: NowNextSnapshot?, at date: Date) -> NowNextEntry {
        NowNextEntry(date: date, now: snapshot?.now(at: date) ?? [], next: snapshot?.next(after: date) ?? [],
                     updatedAt: snapshot?.updatedAt)
    }

    static let sample: NowNextEntry = {
        let start = Date.now.addingTimeInterval(-10 * 60)
        return NowNextEntry(
            date: .now,
            now: [.init(id: "sample-now", title: "Opening keynote", place: "Centre Stage", start: start,
                        end: start.addingTimeInterval(45 * 60), mine: true, url: nil)],
            next: [.init(id: "sample-next", title: "AI in the newsroom", place: "Media Village",
                         start: start.addingTimeInterval(60 * 60), end: nil, mine: false, url: nil)],
            updatedAt: .now)
    }()
}

struct NowNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowNextEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (NowNextEntry) -> Void) {
        let snapshot = SharedContainer.readNowNext()
        completion(context.isPreview && snapshot == nil ? .sample : .make(from: snapshot, at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowNextEntry>) -> Void) {
        let now = Date.now
        let snapshot = SharedContainer.readNowNext()
        let horizon = now.addingTimeInterval(12 * 3_600)
        let changes = snapshot?.changes(after: now, until: horizon) ?? []
        let entries = ([now] + changes.prefix(40)).map { NowNextEntry.make(from: snapshot, at: $0) }
        // Ask again in an hour at the latest; the app also reloads us when it writes a new snapshot.
        completion(Timeline(entries: entries, policy: .after(min(changes.last ?? horizon, now.addingTimeInterval(3_600)))))
    }
}

struct NowNextWidget: Widget {
    /// Opens the schedule in the app shell (promptugal://open/<destination id>).
    static let scheduleURL = URL(string: "promptugal://open/team.schedule")!

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedContainer.nowNextKind, provider: NowNextProvider()) { entry in
            NowNextView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(NowNextWidget.scheduleURL)
        }
        .configurationDisplayName("Now and next")
        .description("The session happening now and what comes next, in Lisbon time.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct NowNextView: View {
    /// The app's red (Palette.red, light), so the widget matches the app without importing PTCore.
    static let red = Color(red: 173 / 255, green: 34 / 255, blue: 43 / 255)
    @Environment(\.widgetFamily) private var family
    let entry: NowNextEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            if let item = entry.next.first {
                Text("\(LisbonClock.time(item.start)) \(item.title)")
            } else {
                Text("PrompTugal")
            }
        case .accessoryRectangular:
            if let item = entry.now.first ?? entry.next.first {
                VStack(alignment: .leading) {
                    Text(entry.now.first == nil ? "Next · \(LisbonClock.time(item.start))" : "Now")
                        .font(.caption2.weight(.semibold))
                    Text(item.title).font(.headline).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No sessions coming up").font(.caption)
            }
        default:
            list
        }
    }

    private var list: some View {
        let limit = family == .systemSmall ? 1 : 2
        return VStack(alignment: .leading, spacing: 6) {
            // The app's softer look (redesign round 3): the name in sentence case, in the app's red.
            Text(verbatim: "PrompTugal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Self.red)
            if entry.now.isEmpty && entry.next.isEmpty {
                Spacer(minLength: 0)
                Text(entry.updatedAt == nil ? "Open PrompTugal to load the agenda." : "No sessions coming up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.now.prefix(limit)) { row($0, label: "Now") }
                ForEach(entry.next.prefix(family == .systemSmall && !entry.now.isEmpty ? 0 : limit)) {
                    row($0, label: LisbonClock.time($0.start))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ item: NowNextSnapshot.Item, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label).font(.caption.weight(.semibold).monospacedDigit())
                if item.mine { Image(systemName: "star.fill").font(.caption2).foregroundStyle(Self.red) }
            }
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(item.place).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
