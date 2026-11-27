import PTCore
import SwiftUI

// Compact pieces of the live newsroom for other screens (PTPlaces' hooks):
//
//   PlacesHomeView()
//       .placesHomeAccessory { AnyView(NewsroomLiveSection()) }
//       .placeAccessory { id in AnyView(TownNewsroomLive(placeID: id)) }
//
// Both share LiveNewsroom.shared, so the dashboard is read once a minute however many are on screen. Read-only.

// MARK: - A face per agent

/// An agent as a round face: its initials on its colour (a town's own accent), a pulse while it shows a sign of life
/// in the last half hour. Still under Reduce Motion, with a steady halo instead.
struct AgentFace: View {
    let role: String
    let color: Color
    let activity: Double
    var size: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if activity > 0 {
                if reduceMotion {
                    Circle().fill(color.opacity(0.25 * activity)).frame(width: size + 10, height: size + 10)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                        let seed = Double(abs(role.hashValue % 100)) / 100
                        let phase = (context.date.timeIntervalSinceReferenceDate / 2.4 + seed).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(color.opacity((1 - phase) * 0.8 * activity), lineWidth: 2)
                            .frame(width: size, height: size)
                            .scaleEffect(1 + phase * 0.55)
                    }
                }
            }
            Circle().fill(color)
            Text(Self.initials(role)).font(.system(size: size * 0.36, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Two letters for a face: a town's initials ("Vila do Bispo" → "VB", "Faro" → "Fa"), else the desk's ("abp" → "Ab").
    static func initials(_ role: String) -> String {
        let id = role.hasPrefix("place.") ? String(role.dropFirst("place.".count)) : nil
        if let id, let name = PlaceDirectory.info(id)?.name {
            let words = name.split(separator: " ").filter { $0.count > 2 && $0.lowercased() != "the" }
            if words.count >= 2 { return words.prefix(2).map { String($0.prefix(1)).uppercased() }.joined() }
            return String((words.first ?? Substring(name)).prefix(2))
        }
        let head = role.split(separator: ".").first.map(String.init) ?? role
        return String(head.prefix(2)).capitalized
    }

    /// A town agent's colour is its site's accent; a desk's is stable for its name.
    @MainActor static func color(for role: String, places: [String: PlaceSite]) -> Color {
        if role.hasPrefix("place."), let accent = places[String(role.dropFirst("place.".count))]?.look?.accent {
            return Color(hex: accent)
        }
        return Palette.stable(role)
    }
}

// MARK: - The places home: the newsroom, live

/// For the places home: who is at work right now (a row of faces, the most recent first, pulsing) and the latest
/// three lines of the ticker; tap through to the full live board.
public struct NewsroomLiveSection: View {
    @State private var model = LiveNewsroom.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .task { await model.run() }
    }

    private func content(now: Date) -> some View {
        let recent = Self.recentAgents(model.dashboard, now: now, limit: sizeClass == .regular ? 10 : 7)
        let working = model.dashboard?.agents.filter { model.activity($0.role, now: now) > 0 }.count ?? 0
        return VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalText.string("The newsroom, live")).font(.system(.title2, design: .serif, weight: .black)).foregroundStyle(Palette.ink)
                Text(Self.subtitle(working: working, total: model.dashboard?.agents.count))
                    .font(.system(.subheadline, design: .serif).italic()).foregroundStyle(Palette.red)
            }
            Rectangle().fill(Palette.ink).frame(height: 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.m) {
                    ForEach(recent) { agent in
                        NavigationLink { NewsroomLiveView(selecting: agent.role) } label: {
                            VStack(spacing: 4) {
                                AgentFace(role: agent.role, color: AgentFace.color(for: agent.role, places: model.places),
                                          activity: model.activity(agent.role, now: now))
                                    .padding(6)
                                Text(agent.placeName ?? NewsroomLayout.short(agent.role)).font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.ink).lineLimit(1)
                                if let date = agent.lastSign(now: now) {
                                    Text(LiveTicker.ago(date, now: now)).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                                }
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(agent.handle), \(agent.status.label)")
                    }
                }
            }
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(model.events.prefix(3)) { event in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Image(systemName: event.symbol).font(.caption).foregroundStyle(Palette.muted).frame(width: 16)
                        Text(event.text).font(.footnote).foregroundStyle(Palette.ink).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(LiveTicker.ago(event.date, now: now)).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.45), value: model.events.first?.id)
            NavigationLink { NewsroomLiveView() } label: {
                Label(LocalText.string("Watch the newsroom in action"), systemImage: "waveform.path.ecg").font(.footnote.weight(.semibold))
            }
            ProvenanceLabel(provenance: model.provenance, phase: model.phase,
                            readAt: model.dashboard?.updated)
        }
    }

    static func subtitle(working: Int, total: Int?) -> String {
        guard let total else { return LocalText.string("Reading the agents…") }
        return LocalText.string("\(String(describing: working)) of \(String(describing: total)) agents active in the last half hour")
    }

    /// The agents with the latest sign of life first.
    static func recentAgents(_ dashboard: NewsroomDashboard?, now: Date, limit: Int) -> [NewsroomDashboard.Agent] {
        struct Seen { let agent: NewsroomDashboard.Agent; let at: Date }
        var seen: [Seen] = []
        for agent in dashboard?.agents ?? [] {
            if let at = agent.lastSign(now: now) { seen.append(Seen(agent: agent, at: at)) }
        }
        seen.sort { a, b in
            if a.at != b.at { return a.at > b.at }
            return a.agent.role < b.agent.role
        }
        return seen.prefix(limit).map(\.agent)
    }
}

// MARK: - A place page: its agent at work

/// For a place's page: the place's own agent, what it says it is doing, its last sign of life, where it fired in the
/// last 24 hours and its latest lines in the ticker; tap through to it on the live board.
public struct TownNewsroomLive: View {
    let placeID: String
    @State private var model = LiveNewsroom.shared

    public init(placeID: String) { self.placeID = placeID }

    private var role: String { "place.\(placeID)" }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .task { await model.run() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(LocalText.string("Its agent at work")).font(.system(.title3, design: .serif, weight: .black)).foregroundStyle(Palette.ink)
            Rectangle().fill(Palette.ink).frame(height: 1)
            if let agent = model.agent(role) {
                HStack(alignment: .top, spacing: Space.m) {
                    AgentFace(role: role, color: AgentFace.color(for: role, places: model.places),
                              activity: model.activity(role, now: now), size: 44)
                        .padding(6)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: Space.s) {
                            Text(content: agent.agent).font(.footnote.monospaced()).foregroundStyle(Palette.ink).lineLimit(1)
                            StatusDot(status: agent.status)
                        }
                        if let date = agent.lastSign(now: now) {
                            Text(LocalText.string("\(String(describing: agent.status.label)) · last sign of life \(String(describing: LiveTicker.ago(date, now: now)))"))
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        if let state = agent.state {
                            Text(content: state).font(.footnote).foregroundStyle(Palette.ink).lineLimit(3)
                        }
                        if let next = agent.next.first {
                            Text(LocalText.string("Next: \(String(describing: next))")).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                        }
                    }
                }
                if let fired = model.extras?.agents[role]?.fired, !fired.isEmpty {
                    HStack(spacing: Space.s) {
                        Text("24 h").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                        HourStrip(fired: fired, color: AgentFace.color(for: role, places: model.places),
                                  currentHour: model.extras.flatMap { WakeGrid.currentIndex(hours: $0.gridHours, now: now) })
                            .frame(height: 8)
                    }
                }
                let lines = model.events.filter { $0.role == role }.prefix(3)
                ForEach(Array(lines)) { event in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Image(systemName: event.symbol).font(.caption2).foregroundStyle(Palette.muted)
                        Text(event.detail ?? event.text).font(.caption).foregroundStyle(Palette.ink).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(LiveTicker.ago(event.date, now: now)).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                    }
                }
                NavigationLink { NewsroomLiveView(selecting: role) } label: {
                    Label(LocalText.string("See it on the live board"), systemImage: "waveform.path.ecg").font(.footnote.weight(.semibold))
                }
            } else if model.dashboard == nil {
                HStack(spacing: Space.s) {
                    ProgressView().controlSize(.small)
                    Text(LocalText.string("Reading the newsroom…")).font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                Text(LocalText.string("The newsroom dashboard lists no agent for this place yet.")).font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
