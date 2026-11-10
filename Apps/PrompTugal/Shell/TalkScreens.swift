import PTAgenda
import PTCore
import PTExplore
import SwiftUI

/// The one native talk detail of the app (EXP-D): PTExplore's `TalkDetailView` with the app's pick star and Add to Calendar
/// plugged in. The agenda rows, My program and Explore all open it, so a talk looks and works the same, offline too.
enum AppTalks {
    @MainActor static var actions: TalkActions {
        TalkActions(pick: { AnyView(TalkPickButton(talk: $0)) },
                    calendar: { talk in
                        AnyView(VStack(spacing: Space.s) {
                            TalkCalendarButton(talk: talk)
                            TalkMapLink(talk: talk)
                        })
                    })
    }
}

/// The agenda's copy of a talk, matched by the page's slug.
@MainActor private func agendaEvent(for talk: TalkRef, in reader: ReaderStore) -> Event? {
    reader.agenda.first { ScheduleID.fromPage($0.page) == talk.slug }
}

/// The pick, as a large button. Without the agenda (first launch, offline) the talk cannot be picked yet.
private struct TalkPickButton: View {
    let talk: TalkRef
    @Environment(ReaderStore.self) private var reader

    var body: some View {
        if let event = agendaEvent(for: talk, in: reader) {
            let picked = reader.isSaved(event)
            Button { reader.toggleSaved(event) } label: {
                Label(picked ? "In my program" : "Add to my program", systemImage: picked ? "star.fill" : "star")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("pt.talk.pick")
        } else {
            Text("Connect to load this talk's times and add it to your program.")
                .font(.footnote).foregroundStyle(Palette.muted)
        }
    }
}

private struct TalkCalendarButton: View {
    let talk: TalkRef
    @Environment(ReaderStore.self) private var reader
    @State private var message: String?

    var body: some View {
        if let event = agendaEvent(for: talk, in: reader) {
            VStack(spacing: Space.s) {
                Button { Task { await add(event) } } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if let message { Text(message).font(.footnote).foregroundStyle(Palette.muted) }
            }
        }
    }

    private func add(_ event: Event) async {
        guard let slug = ScheduleID.fromPage(event.page) else { return }
        let pick = SchedulePick(id: slug, at: .now, event: event)
        switch await CalendarExport.add([pick]) {
        case .added(let count): message = count == 0 ? String(localized: "This talk has no time yet.") : String(localized: "Added to your calendar.")
        case .denied: message = String(localized: "Calendar access is off. Allow it in Settings to add talks.")
        case .failed(let text): message = text
        }
    }
}

/// "Show on the map": the venue map, with today's picks and the walks, one tap from the talk.
/// A sheet, not a push: the talk detail is a List, where a navigation destination would be ignored.
private struct TalkMapLink: View {
    let talk: TalkRef
    @State private var showing = false

    var body: some View {
        if let place = talk.place, !place.isEmpty {
            Button { showing = true } label: {
                Label("Show on the map", systemImage: "map").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint(Text(place))
            .accessibilityIdentifier("pt.talk.map")
            .sheet(isPresented: $showing) {
                NavigationStack {
                    VenueMapView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { showing = false } }
                        }
                }
            }
        }
    }
}

/// A talk opened from the agenda or My program, shown over the screen it was opened from.
struct TalkSheetItem: Identifiable {
    let talk: TalkRef
    var id: String { talk.slug }
}

extension View {
    /// Presents the shared talk detail in a sheet for the bound talk.
    func talkSheet(_ item: Binding<TalkSheetItem?>) -> some View {
        sheet(item: item) { opened in
            NavigationStack {
                TalkDetailView(talk: opened.talk, actions: AppTalks.actions)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { item.wrappedValue = nil } }
                    }
            }
        }
    }
}

/// My program with the app's wiring: "Choose talks" opens Explore, a row opens the shared talk detail.
struct MyProgramScreen: View {
    @Environment(\.openDestination) private var openDestination
    @Environment(\.openURL) private var openURL
    @Environment(ReaderStore.self) private var reader
    @State private var opened: TalkSheetItem?

    var body: some View {
        MyProgramView(chooseTalks: { openDestination("explore") }, open: { url in
            if let event = reader.agenda.first(where: { $0.url == url }) {
                opened = TalkSheetItem(talk: TalkRef(event))
            } else {
                openURL(url)
            }
        })
        .talkSheet($opened)
    }
}
