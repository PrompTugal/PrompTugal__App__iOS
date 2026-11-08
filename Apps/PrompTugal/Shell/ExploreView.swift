import PTAgenda
import PTCore
import PTExplore
import PTNews
import PTWeb
import SwiftUI

/// Where Explore opens. The shell sets it from the id that was opened (explore, explore.people, explore.talk, ...).
private struct ExploreStartKey: EnvironmentKey {
    static let defaultValue: ExploreStart = .talks
}

extension EnvironmentValues {
    var exploreStart: ExploreStart {
        get { self[ExploreStartKey.self] }
        set { self[ExploreStartKey.self] = newValue }
    }
}

/// Explore (ux spec EXP-1): PTExplore's screen with the app's views plugged in: the agenda list for Talks (PTExplore cannot
/// see PTAgenda), a native talk detail with the pick star and Add to Calendar, the graph card once there are three picks,
/// and the graph itself. The screen brings its own navigation stack.
struct ExploreView: View {
    @Environment(\.exploreStart) private var start
    @Environment(ReaderStore.self) private var reader

    var body: some View {
        ExploreScreen(hooks: hooks, start: start)
            // A different start (a link to another segment) builds the screen again at that segment.
            .id(Self.key(start))
    }

    private var hooks: ExploreHooks {
        ExploreHooks(
            talks: { AnyView(AgendaView()) },
            talkDetail: { item in AnyView(TalkDetailView(item: item)) },
            header: { AnyView(GraphCard(picks: reader.saved.count)) },
            graph: { AnyView(GraphExplorerView()) })
    }

    private static func key(_ start: ExploreStart) -> String {
        switch start {
        case .talks: "talks"
        case .speakers: "speakers"
        case .companies: "companies"
        case .places: "places"
        case .talk(let ref): "talk:" + (ref ?? "")
        case .graph: "graph"
        }
    }
}

/// EXP-G: the graph, offered once the person has three or more picks (no empty graphs). The scoped graph (only the people
/// and companies behind the picks) is not built yet, so the card opens the full graph and says so.
private struct GraphCard: View {
    let picks: Int

    var body: some View {
        if picks >= 3 {
            NavigationLink {
                GraphExplorerView()
            } label: {
                Card {
                    HStack(spacing: Space.m) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2).foregroundStyle(Palette.red)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Explore the summit graph").font(Typo.headline).foregroundStyle(Palette.ink)
                            Text("Companies, people and events").font(.footnote).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: Space.s)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Space.l)
            .accessibilityIdentifier("pt.explore.graph")
        }
    }
}

/// EXP-D: a talk, natively: title, day and time, place, the pick star as a large button, Add to Calendar, and the page on
/// promptugal.news. It reads the agenda for the talk's own times; the index's strings are the fallback.
private struct TalkDetailView: View {
    let item: ExploreItem

    @Environment(ReaderStore.self) private var reader
    @State private var calendarMessage: String?

    /// The agenda's copy of this talk, matched by the page's slug.
    private var event: Event? {
        reader.agenda.first { ScheduleID.fromPage($0.page) == item.slug }
    }

    private var picked: Bool { event.map(reader.isSaved) ?? false }

    var body: some View {
        Page(maxWidth: 700) {
            VStack(alignment: .leading, spacing: Space.s) {
                Kicker("Lisbon · 9–12 Nov")
                Text(item.title).font(Typo.title).foregroundStyle(Palette.ink)
                if let when { Text(when).font(Typo.data).foregroundStyle(Palette.muted) }
                if let place { Text(place).font(.subheadline).foregroundStyle(Palette.ink) }
            }
            if !item.text.isEmpty, item.text != item.title {
                Text(item.text).font(.body).foregroundStyle(Palette.muted)
            }
            if let event {
                Button { reader.toggleSaved(event) } label: {
                    Label(picked ? "In my program" : "Add to my program", systemImage: picked ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("pt.talk.pick")
                Button { Task { await addToCalendar(event) } } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if let calendarMessage {
                    Text(calendarMessage).font(.footnote).foregroundStyle(Palette.muted)
                }
            } else {
                Text("Connect to load this talk's times and add it to your program.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            if let page = item.page ?? event?.url {
                Link(destination: page) { Label("Open on promptugal.news", systemImage: "safari") }
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("Talk")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var when: String? {
        if let start = event?.start {
            let end = event?.end.map { " – " + Lisbon.timeLabel($0) } ?? ""
            return Lisbon.dayLabel(Lisbon.day(start)) + " · " + Lisbon.timeLabel(start) + end
        }
        guard let day = item.day, let start = item.start else { return nil }
        return Lisbon.dayLabel(day) + " · " + start + (item.end.map { " – " + $0 } ?? "")
    }

    private var place: String? {
        let text = event?.place ?? item.subtitle
        return text.isEmpty ? nil : text
    }

    private func addToCalendar(_ event: Event) async {
        guard let slug = ScheduleID.fromPage(event.page) else { return }
        let pick = SchedulePick(id: slug, at: .now, event: event)
        switch await CalendarExport.add([pick]) {
        case .added(let count): calendarMessage = count == 0 ? "This talk has no time yet." : "Added to your calendar."
        case .denied: calendarMessage = "Calendar access is off. Allow it in Settings to add talks."
        case .failed(let message): calendarMessage = message
        }
    }
}
