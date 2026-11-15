import PTCore
import PTLanes
import PTLocal
import SwiftUI

/// A conversation with a town's agent. What the owner writes is sealed to the agent's lane when it has one (none
/// has yet: the screen says so and keeps the message here). Meanwhile Apple Intelligence answers on this device from
/// the town's own published data, and every such answer is labelled that way.
struct TownAgentView: View {
    let town: PlaceInfo

    @State private var lanes = TalkLanes.shared
    @State private var history = TalkHistory.shared
    @State private var store = LocalStore.shared
    @State private var sender = TalkSender()
    @State private var draft = ""
    @State private var answering = false
    @State private var askDevice = true
    @FocusState private var focused: Bool

    private var lane: SealedLane? { lanes.agent(town.id) }

    var body: some View {
        VStack(spacing: 0) {
            banner
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.m) {
                        let lines = history.lines(town.id)
                        if lines.isEmpty {
                            Text("Ask about \(town.name): its AI news, who is on its AI map, what is on. The answer comes from the town's published data until its agent has a lane.")
                                .font(.footnote).foregroundStyle(Palette.muted).padding(.top, Space.l)
                        }
                        ForEach(lines) { line in
                            Bubble(line: line, agent: town.agent).id(line.id)
                        }
                    }
                    .padding(Space.l)
                }
                .onChange(of: history.lines(town.id).last?.text) { _, _ in
                    if let last = history.lines(town.id).last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Palette.paper)
        .navigationTitle(town.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if store.site(town.id) == nil { await store.refreshPlaces() } }
    }

    // MARK: Parts

    private var banner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: lane == nil ? "tray" : "lock.shield").foregroundStyle(lane == nil ? Palette.amber : Palette.green)
                Text(town.agent).font(.caption.monospaced()).foregroundStyle(Palette.ink)
            }
            if let lane {
                Text("Messages are sealed to this agent's key (\(lane.fingerprint)) and appended to its lane.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            } else {
                Text("This agent has no lane yet: your messages are kept on this device, not sent.")
                    .font(.caption2).foregroundStyle(Palette.amber)
            }
            HStack(spacing: 6) {
                Image(systemName: "apple.intelligence").foregroundStyle(Palette.blue)
                if let why = TownAnswerer.unavailableReason {
                    Text("On-device answers: \(why)").font(.caption2).foregroundStyle(Palette.muted)
                } else {
                    Toggle(isOn: $askDevice) {
                        Text("Answer on this device from \(store.placeProvenance.label.lowercased())").font(.caption2).foregroundStyle(Palette.muted)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
            if case .retrying = sender.state {
                SendStatusView(state: sender.state, recipient: town.agent, onTryNow: { sender.tryNow() })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(Palette.paper2)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            TextField("Ask \(town.name)", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { Task { await send() } }
                .accessibilityIdentifier("pt.talk.agent.text")
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answering || sender.state.isBusy)
            .accessibilityIdentifier("pt.talk.agent.send")
        }
        .padding(Space.m)
        .background(.bar)
    }

    // MARK: Sending and answering

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        let mine = history.append(.init(role: .me, text: text, delivery: lane == nil ? .kept : nil), to: town.id)

        if let lane {
            let item = TalkWire.itemId(purpose: .agent, town: town.id)
            if let messages = try? TalkWire.messages(item: item, purpose: .agent, to: town.agent, town: town.id, townName: town.name,
                                                     text: text, app: TalkApp.line) {
                Task {
                    let ok = await sender.send(messages, to: lane)
                    history.update(mine, in: town.id) { $0.delivery = ok ? .sent : .failed }
                }
            }
        }

        guard askDevice else { return }
        guard let site = store.site(town.id) else {
            history.append(.init(role: .note, text: "The town's published data is not loaded yet, so there is no on-device answer."), to: town.id)
            return
        }
        if let why = TownAnswerer.unavailableReason {
            history.append(.init(role: .note, text: "No on-device answer: \(why)"), to: town.id)
            return
        }
        answering = true
        defer { answering = false }
        let source = store.placeProvenance.label
        let answer = history.append(.init(role: .onDevice, text: "…", source: source), to: town.id)
        do {
            let final = try await TownAnswerer.answer(question: text, site: site) { soFar in
                history.update(answer, in: town.id) { $0.text = soFar }
            }
            history.update(answer, in: town.id) { $0.text = final.isEmpty ? "No answer came back." : final }
        } catch {
            history.update(answer, in: town.id) { $0.role = .note; $0.text = "No on-device answer: \(error.localizedDescription)" }
        }
    }
}

struct Bubble: View {
    let line: TalkHistory.Line
    let agent: String

    var body: some View {
        HStack {
            if line.role == .me { Spacer(minLength: 48) }
            VStack(alignment: line.role == .me ? .trailing : .leading, spacing: 4) {
                if line.role == .onDevice {
                    Label(TownAnswerer.label, systemImage: "apple.intelligence")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Palette.blue)
                }
                Text(line.text)
                    .font(line.role == .note ? .footnote : .body)
                    .foregroundStyle(line.role == .note ? Palette.muted : Palette.ink)
                    .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                    .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .textSelection(.enabled)
                footer
            }
            if line.role != .me { Spacer(minLength: 48) }
        }
    }

    private var background: Color {
        switch line.role {
        case .me: Palette.blue.opacity(0.16)
        case .onDevice: Palette.card
        case .note: Palette.paper2
        }
    }

    @ViewBuilder private var footer: some View {
        switch line.role {
        case .me:
            switch line.delivery {
            case .sent: Text("Sealed to \(agent)'s lane").font(.caption2).foregroundStyle(Palette.green)
            case .failed: Text("Not sent").font(.caption2).foregroundStyle(Palette.red)
            case .kept: Text("Kept on this device: no lane yet").font(.caption2).foregroundStyle(Palette.muted)
            case nil: Text("Sending…").font(.caption2).foregroundStyle(Palette.muted)
            }
        case .onDevice:
            if let source = line.source { Text("From the town's data: \(source)").font(.caption2).foregroundStyle(Palette.muted) }
        case .note:
            EmptyView()
        }
    }
}
