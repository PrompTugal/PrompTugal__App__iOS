import PTAgenda
import PTCore
import SwiftUI

/// Round 2 of the redesign: one tap on the star picks a talk and puts it in the phone's calendar. The first pick asks
/// once; the answer is kept and can be changed in More. Write-only access, so the app never reads the calendar.
enum PickCalendarChoice: Int {
    case unasked = 0, yes = 1, no = 2

    static let key = "picks.calendar"
    static let addedKey = "picks.calendar.added"
}

/// Pure rules, so the unit tests can check them without a calendar.
enum PickCalendarRule {
    /// The one talk the person has just picked in the app, or nil. A sync from the website or a restore can add many
    /// picks at once: those never go to the calendar on their own.
    static func newPick(old: [String], new: [String], fromApp: Bool) -> String? {
        guard fromApp else { return nil }
        let added = Set(new).subtracting(old)
        return added.count == 1 ? added.first : nil
    }

    /// The ids already sent to the calendar, kept as one line so a pick taken off and on again is not added twice.
    static func ids(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "\n").map(String.init))
    }

    static func raw(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "\n")
    }
}

extension View {
    /// Watches the picks and adds each new one to the calendar when the person said yes.
    func pickCalendar() -> some View { modifier(PickCalendarHost()) }
}

private struct PickCalendarHost: ViewModifier {
    @Environment(ScheduleStore.self) private var schedule
    @AppStorage(PickCalendarChoice.key) private var choice = PickCalendarChoice.unasked.rawValue
    @AppStorage(PickCalendarChoice.addedKey) private var addedRaw = ""
    @State private var asking: SchedulePick?

    func body(content: Content) -> some View {
        content
            .onChange(of: schedule.picks.map(\.id)) { old, new in
                guard let id = PickCalendarRule.newPick(old: old, new: new, fromApp: schedule.lastChange?.source == .app),
                      let pick = schedule.picks.first(where: { $0.id == id }), pick.start != nil,
                      !PickCalendarRule.ids(addedRaw).contains(id) else { return }
                switch PickCalendarChoice(rawValue: choice) ?? .unasked {
                case .yes: Task { await add(pick) }
                case .unasked: asking = pick
                case .no: break
                }
            }
            .confirmationDialog("Add your picks to your calendar too?",
                                isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                                titleVisibility: .visible, presenting: asking) { pick in
                Button("Add to Calendar too") {
                    choice = PickCalendarChoice.yes.rawValue
                    Task { await add(pick) }
                }
                Button("Not now", role: .cancel) { choice = PickCalendarChoice.no.rawValue }
            } message: { _ in
                Text("Each talk you pick goes into your phone's calendar with its time and hall. You can change this in More.")
            }
    }

    private func add(_ pick: SchedulePick) async {
        switch await CalendarExport.add([pick]) {
        case .added(let count) where count > 0:
            var ids = PickCalendarRule.ids(addedRaw)
            ids.insert(pick.id)
            addedRaw = PickCalendarRule.raw(ids)
        case .denied:
            // Access was refused in iOS: stop trying until the person turns it on again in More.
            choice = PickCalendarChoice.no.rawValue
        default:
            break
        }
    }
}

/// The switch in More.
struct PickCalendarToggle: View {
    @AppStorage(PickCalendarChoice.key) private var choice = PickCalendarChoice.unasked.rawValue

    var body: some View {
        Toggle(isOn: Binding(get: { choice == PickCalendarChoice.yes.rawValue },
                             set: { choice = ($0 ? PickCalendarChoice.yes : PickCalendarChoice.no).rawValue })) {
            Label("Add new picks to my calendar", systemImage: "calendar.badge.plus")
        }
        .accessibilityIdentifier("pt.more.pickCalendar")
    }
}
