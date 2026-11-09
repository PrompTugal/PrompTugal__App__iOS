import PTCore
import SwiftUI

/// Tasks (the redesign, Indi's brief v7, step 5): the team's issues for this person, grouped by day, with starred
/// tasks first as "Priority". Each group folds behind a full-width header. Every tick circle and star is a 44-point
/// target. Ticks and stars are kept on this iPhone until live sync to the team board is switched on (step 5b, waiting
/// for Dinis's yes); the screen says so.
struct TasksView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @AppStorage("tasks.everyone") private var everyone = true
    @AppStorage("tasks.starred") private var starredRaw = ""
    @AppStorage("tasks.doneHere") private var doneRaw = ""
    @AppStorage("tasks.folded") private var foldedRaw = "later"
    @State private var showDone = false

    var body: some View {
        Group {
            if let me = identity.current?.id {
                list(me: me)
                    .task(id: me) { await team.refreshCentre(for: me) }
                    .refreshable { await team.refreshCentre(for: me) }
            } else {
                ContentUnavailableView("Choose who you are", systemImage: "person.crop.circle.badge.questionmark",
                                       description: Text("Pick your name on the Team screen to see your tasks."))
            }
        }
        .navigationTitle("Tasks")
    }

    // MARK: Groups

    enum Bucket: String, CaseIterable, Identifiable {
        case priority, late, today, tomorrow, later
        var id: String { rawValue }
        var title: String {
            switch self {
            case .priority: "★ Priority"
            case .late: "Late"
            case .today: "Today"
            case .tomorrow: "Tomorrow"
            case .later: "Later"
            }
        }
        var colour: Color {
            switch self {
            case .priority: Palette.amber
            case .late: Palette.red
            default: Palette.ink
            }
        }
    }

    func bucket(_ issue: CommandCentre.Issue) -> Bucket {
        if starred.contains(issue.id) { return .priority }
        if issue.isLate { return .late }
        guard let due = issue.dueAt else { return .later }
        let cal = Calendar.current
        if cal.isDateInToday(due) { return .today }
        if cal.isDateInTomorrow(due) { return .tomorrow }
        return due < .now ? .late : .later
    }

    @ViewBuilder
    func list(me: String) -> some View {
        let centre = team.centres[me]
        // Mine = issues that name this person, the same rule as the Now screen's "overdue of open" (team site data).
        let all = (centre?.issues ?? []).filter { everyone || $0.named }
        let open = all.filter { !$0.isDone && !doneHere.contains($0.id) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        let done = all.filter { $0.isDone || doneHere.contains($0.id) }
        List {
            Section {
                Picker("Whose", selection: $everyone) {
                    Text("Mine").tag(false)
                    Text("Everyone").tag(true)
                }
                .pickerStyle(.segmented)
                Label(doneHere.isEmpty && starred.isEmpty ? "From the team board" : "Ticks and stars are saved on this iPhone until live sync is on",
                      systemImage: doneHere.isEmpty && starred.isEmpty ? "checkmark.circle" : "iphone")
                    .font(Typo.meta).foregroundStyle(Palette.muted)
            }
            .listRowBackground(Color.clear)

            if centre == nil {
                ProgressView("Loading tasks…")
            } else if open.isEmpty {
                Text("Nothing open. Well done.").foregroundStyle(Palette.muted)
            }

            ForEach(Bucket.allCases) { b in
                let rows = open.filter { bucket($0) == b }
                if !rows.isEmpty {
                    Section {
                        if !folded.contains(b.rawValue) {
                            ForEach(rows) { issue in TaskRow(issue: issue, done: false, starred: starred.contains(issue.id),
                                                             tick: { toggleDone(issue.id) }, star: { toggleStar(issue.id) }) }
                        }
                    } header: {
                        Button { toggleFold(b.rawValue) } label: {
                            HStack(spacing: Space.s) {
                                Image(systemName: "chevron.down").rotationEffect(.degrees(folded.contains(b.rawValue) ? -90 : 0))
                                Text(b.title).font(.footnote.weight(.bold)).textCase(.uppercase)
                                Spacer()
                                Text("\(rows.count) \(b == .priority ? "starred" : "open")").font(Typo.meta).foregroundStyle(Palette.muted)
                            }
                            .foregroundStyle(b.colour)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(b.title), \(rows.count), \(folded.contains(b.rawValue) ? "folded" : "open")")
                    }
                }
            }

            if !done.isEmpty {
                Section {
                    if showDone {
                        ForEach(done) { issue in TaskRow(issue: issue, done: true, starred: false,
                                                         tick: { if doneHere.contains(issue.id) { toggleDone(issue.id) } }, star: {}) }
                    }
                } header: {
                    Button { showDone.toggle() } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "chevron.down").rotationEffect(.degrees(showDone ? 0 : -90))
                            Text("Completed · \(done.count)").font(.footnote.weight(.bold))
                            Spacer()
                        }
                        .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
    }

    // MARK: Local state (until live sync)

    var starred: Set<String> { Set(starredRaw.split(separator: ",").map(String.init)) }
    var doneHere: Set<String> { Set(doneRaw.split(separator: ",").map(String.init)) }
    var folded: Set<String> { Set(foldedRaw.split(separator: ",").map(String.init)) }

    func toggle(_ id: String, in raw: inout String) {
        var s = Set(raw.split(separator: ",").map(String.init))
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        raw = s.sorted().joined(separator: ",")
    }
    func toggleStar(_ id: String) { withAnimation { toggle(id, in: &starredRaw) } }
    func toggleDone(_ id: String) { withAnimation { toggle(id, in: &doneRaw) } }
    func toggleFold(_ id: String) { withAnimation { toggle(id, in: &foldedRaw) } }
}

struct TaskRow: View {
    let issue: CommandCentre.Issue
    let done: Bool
    let starred: Bool
    let tick: () -> Void
    let star: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Button(action: tick) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(done ? Palette.green : Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark not done: \(Self.clean(issue.title))" : "Mark done: \(Self.clean(issue.title))")
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.clean(issue.title)).strikethrough(done).foregroundStyle(done ? Palette.muted : Palette.ink)
                HStack(spacing: 4) {
                    if !issue.area.isEmpty { Text(issue.area.capitalized) }
                    if !issue.pickedBy.isEmpty { Text("· " + Self.firstName(issue.pickedBy)) }
                    if !issue.due.isEmpty { Text("· " + issue.due).foregroundStyle(issue.isLate && !done ? Palette.red : Palette.muted) }
                    if issue.isLate && !done {
                        Text("Late").font(.caption2.weight(.bold)).foregroundStyle(Palette.red)
                            .padding(.horizontal, 5).background(Palette.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                .font(Typo.meta).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .padding(.vertical, 10)
            Spacer(minLength: 0)
            if !done {
                Button(action: star) {
                    Image(systemName: starred ? "star.fill" : "star").font(.title3)
                        .foregroundStyle(starred ? Palette.amber : Palette.muted).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(starred ? "Remove from Priority" : "Add to Priority")
            }
        }
    }

    /// Issue titles can arrive wrapped in the quotes of their front matter.
    static func clean(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”' "))
    }

    static func firstName(_ s: String) -> String {
        String(s.split(separator: ",").first?.split(separator: " ").first ?? "")
    }
}
