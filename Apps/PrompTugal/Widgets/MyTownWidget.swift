import SwiftUI
import PTNowNext
import WidgetKit

/// "My town": the newest sourced story from each town the person follows, as the app last read it.
/// The widget never touches the network; the app writes the snapshot (MyTownPublisher in PTPlaces).
struct MyTownEntry: TimelineEntry {
    let date: Date
    let snapshot: MyTownSnapshot?

    static let sample = MyTownEntry(date: .now, snapshot: MyTownSnapshot(
        updatedAt: .now, origin: "live",
        towns: [.init(id: "loule", name: "Loulé", story: .init(
            title: "Loulé council tests AI to answer residents' questions", date: "2026-11-26",
            outlet: "Sul Informação", url: URL(string: "https://promptugal.news/")!))]))
}

struct MyTownProvider: TimelineProvider {
    func placeholder(in context: Context) -> MyTownEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (MyTownEntry) -> Void) {
        let snapshot = SharedContainer.readMyTown()
        completion(context.isPreview && snapshot == nil ? .sample : MyTownEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MyTownEntry>) -> Void) {
        // One entry; the app reloads us when it writes a new snapshot, and we redraw every few hours so the
        // story's age ("2 days ago") stays true.
        let now = Date.now
        completion(Timeline(entries: [MyTownEntry(date: now, snapshot: SharedContainer.readMyTown())],
                            policy: .after(now.addingTimeInterval(3 * 3_600))))
    }
}

struct MyTownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedContainer.myTownKind, provider: MyTownProvider()) { entry in
            MyTownView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My town")
        .description("The latest local AI story from the towns you follow, with its source.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct MyTownView: View {
    /// The app's red (Palette.red, light), so the widget matches the app without importing PTCore.
    static let red = Color(red: 173 / 255, green: 34 / 255, blue: 43 / 255)
    @Environment(\.widgetFamily) private var family
    let entry: MyTownEntry

    private var towns: [MyTownSnapshot.Town] { entry.snapshot?.towns ?? [] }

    /// promptugal://open/place:<id>, or the Places tab when nothing is followed.
    private var link: URL {
        URL(string: towns.first.map { "promptugal://open/place:\($0.id)" } ?? "promptugal://open/places")!
    }

    var body: some View {
        content.widgetURL(link)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            if let town = towns.first, let story = town.story {
                Text(verbatim: "\(town.name): \(story.title)")
            } else {
                Text(verbatim: "PrompTugal.news")
            }
        case .accessoryRectangular:
            if let town = towns.first {
                VStack(alignment: .leading) {
                    Text(verbatim: town.name).font(.caption2.weight(.semibold))
                    if let story = town.story {
                        Text(english: story.title).font(.headline).lineLimit(2)
                    } else {
                        Text("No local story yet").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Follow a town in PrompTugal.news").font(.caption)
            }
        default:
            card
        }
    }

    private var card: some View {
        let limit = family == .systemSmall ? 1 : 2
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(verbatim: "PrompTugal.news").font(.caption.weight(.semibold)).foregroundStyle(Self.red)
                Spacer(minLength: 0)
                if let origin = originLabel { Text(origin).font(.caption2).foregroundStyle(.secondary) }
            }
            if towns.isEmpty {
                Spacer(minLength: 0)
                Text(entry.snapshot == nil ? "Open PrompTugal.news and follow your town." : "Follow a town in PrompTugal.news")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(towns.prefix(limit)) { town in
                    if let story = town.story {
                        Link(destination: URL(string: "promptugal://open/place:\(town.id)")!) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: town.name).font(.caption.weight(.semibold))
                                Text(english: story.title).font(.subheadline.weight(.semibold))
                                    .lineLimit(family == .systemSmall ? 4 : 2)
                                Text(verbatim: "\(story.outlet) · \(age(story.date))")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: town.name).font(.caption.weight(.semibold))
                            Text("No local story yet").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Every screen says where its data came from; live data needs no label.
    private var originLabel: LocalizedStringKey? {
        switch entry.snapshot?.origin {
        case "cached": "Saved copy"
        case "built-in": "Built-in copy"
        default: nil
        }
    }

    /// "Today", "Yesterday", or "26 Nov", in the device's language.
    private func age(_ day: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Europe/Lisbon")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(day.prefix(10))) else { return day }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

extension Text {
    /// The site's headlines are English; marked so VoiceOver reads them in an English voice under Portuguese.
    init(english string: String) {
        var text = AttributedString(string)
        text.languageIdentifier = "en"
        self.init(text)
    }
}
