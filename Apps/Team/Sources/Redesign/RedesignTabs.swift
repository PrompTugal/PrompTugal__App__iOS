import PTAgenda
import PTCore
import PTLanes
import SwiftUI

// The redesign's three tabs (Indi's brief v7, stages 2 to 4, from the prototype she chose):
// Now (draft D: the day as one timeline), Where (draft E: faces first), Plan (draft D: each day as a timeline).
// The screens they replace stay under More: My day (classic), Shared plans, My picks.

// MARK: Now

struct NowTabView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(ScheduleStore.self) private var schedule
    @Environment(PlannerStore.self) private var planner
    @Environment(\.agendaTeam) private var agendaTeam
    @AppStorage("tasks.starred") private var starredRaw = ""
    @AppStorage("tasks.doneHere") private var doneRaw = ""
    @State private var share = PlaceShare.shared

    var body: some View {
        let me = identity.current
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(spacing: Space.m) {
                    Avatar(initials: (me?.name ?? "?").split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased(),
                           colour: Color(teamHex: me?.colour ?? "") ?? Palette.amber, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.greeting).font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                        Text(me.map { String($0.name.split(separator: " ").first ?? "") } ?? "Choose who you are").font(Typo.title)
                    }
                }
                PlaceCard(me: me?.id)
                Text("YOUR DAY").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                TimelineView(.everyMinute) { _ in
                    DayTimeline(rows: DayRows.rows(day: Lisbon.day(.now), schedule: schedule, team: agendaTeam, planner: planner, me: me?.id),
                                nowLine: share.mine.flatMap { $0.until > .now ? "\($0.place.label), shared with the team" : nil } ?? "Tap where you are above")
                }
                if let me, let centre = team.centres[me.id] {
                    let starred = Set(starredRaw.split(separator: ",").map(String.init))
                    let done = Set(doneRaw.split(separator: ",").map(String.init))
                    let needs = centre.issues.filter { $0.named && !$0.isDone && !done.contains($0.id) }
                        .sorted { ($0.isLate ? 0 : 1, $0.dueAt ?? .distantFuture) < ($1.isLate ? 0 : 1, $1.dueAt ?? .distantFuture) }
                        .prefix(3)
                    if !needs.isEmpty {
                        HStack {
                            Text("NEEDS YOU").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                            Spacer()
                            Text("\(centre.issues.filter { $0.named && !$0.isDone && $0.isLate && !done.contains($0.id) }.count) late").font(Typo.meta).foregroundStyle(Palette.muted)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(needs)) { issue in
                                TaskRow(issue: issue, done: false, starred: starred.contains(issue.id),
                                        tick: { toggle(issue.id, &doneRaw) }, star: { toggle(issue.id, &starredRaw) })
                                    .padding(.horizontal, Space.s)
                            }
                        }
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(Space.l)
        }
        .background(Palette.paper)
        .navigationTitle("Now")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: me?.id) { if let id = me?.id { await team.refreshCentre(for: id) } }
        .refreshable { if let id = me?.id { await team.refreshCentre(for: id) } }
    }

    static var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING"
    }

    func toggle(_ id: String, _ raw: inout String) {
        var s = Set(raw.split(separator: ",").map(String.init))
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        withAnimation { raw = s.sorted().joined(separator: ",") }
    }
}

// MARK: Where

struct WhereTabView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @State private var share = PlaceShare.shared
    @State private var chosen: TeamPerson?
    @State private var search = ""

    var body: some View {
        let me = identity.current?.id
        let store = me.map { MessagesHub.store(for: $0) }
        let places = store.map { share.team(from: $0) } ?? [:]
        let people = (team.me?.people ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(store?.isSwitchedOn == true
                     ? "Seen by the team only, sealed end to end. Places, never GPS."
                     : "Places, never GPS. Your place is saved on this iPhone; the team sees it once messaging is switched on.")
                    .font(Typo.meta).foregroundStyle(Palette.muted)
                PlaceCard(me: me)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 4), spacing: Space.m) {
                    ForEach(people) { p in
                        let line = p.id == me ? share.mine : places[p.id]
                        Button { chosen = p } label: {
                            VStack(spacing: 4) {
                                PlaceFace(name: p.name, colour: p.colour, place: line)
                                Text(p.id == me ? "You" : p.first).font(.footnote.weight(.semibold)).lineLimit(1)
                                Text(line.map { $0.isStale ? "Not seen" : $0.place.short } ?? "Not shared")
                                    .font(.caption2).foregroundStyle(line.map { $0.isStale ? Palette.muted : $0.place.colour } ?? Palette.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(p.name), \(line?.place.label ?? "place not shared")")
                    }
                }
                .padding(Space.m)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))

                Text("BY PLACE").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(TeamPlace.allCases) { place in
                        let here = people.filter { ($0.id == me ? share.mine : places[$0.id]).map { $0.place == place && !$0.isStale } ?? false }
                        if !here.isEmpty {
                            HStack(alignment: .top) {
                                Label(place.label, systemImage: place.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(place.colour)
                                Spacer()
                                Text(here.map { $0.id == me ? "You" : $0.first }.joined(separator: ", ")).font(.subheadline).multilineTextAlignment(.trailing)
                            }
                            .padding(Space.m).frame(minHeight: 44)
                            Divider()
                        }
                    }
                    NavigationLink { TeamPlansView() } label: {
                        Label("Shared plans: who is together, where to meet", systemImage: "person.2.wave.2").font(.subheadline)
                            .padding(Space.m).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(Space.l)
        }
        .background(Palette.paper)
        .searchable(text: $search, prompt: "Find a person")
        .navigationTitle("Where")
        .navigationBarTitleDisplayMode(.inline)
        .task { if team.me == nil { await team.refresh(person: me) } }
        .sheet(item: $chosen) { p in PersonPlaceSheet(person: p, line: p.id == me ? share.mine : places[p.id], me: me) }
    }
}

private struct PersonPlaceSheet: View {
    let person: TeamPerson
    let line: PlaceLine?
    let me: String?
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(spacing: Space.m) {
                    PlaceFace(name: person.name, colour: person.colour, place: line, size: 60)
                    VStack(alignment: .leading) {
                        Text(person.name).font(Typo.title)
                        Text(person.role).font(Typo.meta).foregroundStyle(Palette.muted)
                    }
                }
                if let line {
                    LabeledContent("Where", value: line.place.label)
                    LabeledContent(line.place == .hotel || line.place == .town || line.place == .off ? "Back" : "Until",
                                   value: line.until.formatted(date: .omitted, time: .shortened))
                    LabeledContent("Updated", value: line.at.formatted(.relative(presentation: .named)))
                } else {
                    Text("\(person.first) has not shared a place yet.").foregroundStyle(Palette.muted)
                }
                if person.id != me {
                    let myPlace = PlaceShare.shared.mine.map { $0.place.label.lowercased() } ?? "where I am"
                    let ask = "Can you come over? I'm \(myPlace). \(me.map { String($0.prefix(1)).uppercased() + $0.dropFirst() } ?? "")"
                    if let me, MessagesHub.store(for: me).isSwitchedOn {
                        Button {
                            Task {
                                do { try await MessagesHub.store(for: me).send(text: ask, to: [person.id]); note = "Sent to \(person.first)." }
                                catch { note = error.localizedDescription }
                            }
                        } label: { Label("Ask to come over", systemImage: "figure.walk").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.borderedProminent).tint(Palette.red)
                    }
                    ShareLink(item: ask) { Label("Ask on WhatsApp or Messages", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.bordered)
                    if let note { Text(note).font(Typo.meta).foregroundStyle(Palette.muted) }
                }
                Spacer()
            }
            .padding(Space.l)
            .background(Palette.paper)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Plan

struct PlanTabView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(ScheduleStore.self) private var schedule
    @Environment(PlannerStore.self) private var planner
    @Environment(\.agendaTeam) private var agendaTeam
    @State private var day = DayRows.summitDays.contains(Lisbon.day(.now)) ? Lisbon.day(.now) : DayRows.summitDays[0]
    @State private var newMeetup = false
    @State private var meetups = MeetupStore.shared

    var body: some View {
        let me = identity.current?.id
        let days = Array(Set(DayRows.summitDays + [Lisbon.day(.now)])).sorted().filter { $0 >= Lisbon.day(.now) || DayRows.summitDays.contains($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Picker("Day", selection: $day) {
                    ForEach(days, id: \.self) { Text(DayRows.shortLabel($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                DayTimeline(rows: DayRows.rows(day: day, schedule: schedule, team: agendaTeam, planner: planner, me: me),
                            nowLine: day == Lisbon.day(.now) ? (PlaceShare.shared.mine.flatMap { $0.until > .now ? $0.place.label : nil } ?? "") : nil)
                    .id(meetups.all.count)
                if let me, let centre = team.centres[me] {
                    let due = centre.issues.filter { $0.named && !$0.isDone && $0.dueAt.map { Lisbon.day($0) == day } == true }
                    if !due.isEmpty {
                        Text("DUE THIS DAY").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(due) { issue in
                                HStack {
                                    Text(TaskRow.clean(issue.title)).font(.subheadline)
                                    Spacer()
                                    Text(issue.dueAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "").font(Typo.meta).foregroundStyle(Palette.muted)
                                }
                                .padding(Space.m).frame(minHeight: 44)
                                Divider()
                            }
                        }
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                NavigationLink { MyDayView(title: "My picks") } label: {
                    Label("My picks, the planner and the calendar", systemImage: "star").font(.subheadline)
                        .padding(Space.m).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(Space.l)
        }
        .background(Palette.paper)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newMeetup = true } label: { Label("New meetup", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $newMeetup) { MeetupSheet(me: me, people: team.me?.people ?? [], day: day) }
        .task(id: me) { if let me { await team.refreshCentre(for: me) } }
    }
}

private struct MeetupSheet: View {
    let me: String?
    let people: [TeamPerson]
    let day: String
    @Environment(\.dismiss) private var dismiss
    @State private var what = "Coffee"
    @State private var place = "Our stand"
    @State private var when = 30
    @State private var who: Set<String> = []
    @State private var saved: Meetup?
    @State private var note: String?

    let whats = ["Coffee", "Lunch", "Debrief", "Demo", "Drinks"]
    let places = ["Our stand", "Food trucks", "Pavilion 5", "In town"]
    let whens = [(15, "In 15 min"), (30, "In 30 min"), (60, "In 1 hour"), (120, "In 2 hours")]

    var body: some View {
        NavigationStack {
            Form {
                if let saved {
                    Section {
                        Text(saved.text)
                        ShareLink(item: saved.text) { Label("Tell the WhatsApp group", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                        if let note { Text(note).font(Typo.meta).foregroundStyle(Palette.muted) }
                    } header: { Text("Added to Plan") }
                } else {
                    Section("What") { chips(whats, selected: what) { what = $0 } }
                    Section("Where") { chips(places, selected: place) { place = $0 } }
                    Section("When") { chips(whens.map { $0.1 }, selected: whens.first { $0.0 == when }?.1 ?? "") { l in when = whens.first { $0.1 == l }?.0 ?? 30 } }
                    Section("Who") {
                        FlowRow {
                            ForEach(people.filter { $0.id != me }) { p in
                                let on = who.contains(p.id)
                                Button(p.first) { if on { who.remove(p.id) } else { who.insert(p.id) } }
                                    .padding(.horizontal, Space.m).frame(minHeight: 44)
                                    .background(on ? Palette.ink : Palette.paper2, in: Capsule())
                                    .foregroundStyle(on ? Palette.card : Palette.ink)
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New meetup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(saved == nil ? "Cancel" : "Done") { dismiss() } }
                if saved == nil { ToolbarItem(placement: .confirmationAction) { Button("Add") { add() } } }
            }
        }
    }

    func chips(_ options: [String], selected: String, pick: @escaping (String) -> Void) -> some View {
        FlowRow {
            ForEach(options, id: \.self) { o in
                Button(o) { pick(o) }
                    .padding(.horizontal, Space.m).frame(minHeight: 44)
                    .background(o == selected ? Palette.ink : Palette.paper2, in: Capsule())
                    .foregroundStyle(o == selected ? Palette.card : Palette.ink)
                    .buttonStyle(.plain)
            }
        }
    }

    func add() {
        let names = people.filter { who.contains($0.id) }.map(\.first)
        let m = Meetup(what: what, place: place, start: Date.now.addingTimeInterval(TimeInterval(when * 60)), people: names)
        MeetupStore.shared.add(m)
        saved = m
        guard let me else { return }
        let store = MessagesHub.store(for: me)
        guard store.isSwitchedOn else { note = "The team hears about it through WhatsApp until messaging is switched on."; return }
        Task {
            do { try await store.send(text: "Meetup: " + m.text, to: Array(who), group: nil); note = "Sent to \(names.joined(separator: ", ")) in Messages." }
            catch { note = error.localizedDescription }
        }
    }
}
