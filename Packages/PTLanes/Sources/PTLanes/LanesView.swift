import SwiftUI
import PTCore

/// Messages: notes to the newsroom, messages to teammates' lanes, my inbox. Entry view for `collab.lanes`.
public struct LanesView: View {
    var store: LanesStore = .shared
    @State private var composing: Compose?
    @State private var addingLane = false
    @State private var showInboxSetup = false
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    @Environment(\.horizontalSizeClass) private var width

    public init(store: LanesStore = .shared) { self.store = store }

    enum Compose: Identifiable {
        case newsroom
        case lane(LaneAddress)
        var id: String {
            switch self {
            case .newsroom: "newsroom"
            case .lane(let address): address.id
            }
        }
    }

    public var body: some View {
        Group {
            if width == .regular {
                // iPad: two columns when there is room (full screen, wide Split View), one list otherwise.
                GeometryReader { geometry in
                    if geometry.size.width >= 700 {
                        HStack(spacing: 0) {
                            List { sendSections }
                                .listStyle(.insetGrouped)
                                .frame(width: min(420, geometry.size.width * 0.42))
                            Divider()
                            List { readSections }
                                .listStyle(.insetGrouped)
                        }
                    } else {
                        List {
                            sendSections
                            readSections
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            } else {
                List {
                    sendSections
                    readSections
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Messages")
        .sheet(item: $composing) { target in
            NavigationStack { LaneComposeView(store: store, target: target) }
                .presentationSizing(.form)
        }
        .sheet(isPresented: $addingLane) {
            NavigationStack { AddLaneView(store: store) }.presentationDetents([.medium, .large]).presentationSizing(.form)
        }
        .sheet(isPresented: $showInboxSetup) {
            NavigationStack { InboxSetupView(store: store) }.presentationDetents([.medium, .large]).presentationSizing(.form)
        }
    }

    @ViewBuilder private var sendSections: some View {
        Section {
            Button {
                composing = .newsroom
            } label: {
                Label("Note to the newsroom", systemImage: "newspaper")
            }
        } header: {
            Text("Newsroom")
        } footer: {
            Text(CollabHooks.vault == nil
                 ? "Notes go to your newsroom notes lane, a vault of your own the newsroom reads with its read key. This needs the vault on this build; until then, add the newsroom's append lane below if it gives you one."
                 : "Notes go to your newsroom notes lane: a vault of your own that the newsroom reads with its read key. Nothing comes back through it.")
        }
        Section {
            if store.visibleLanes.isEmpty {
                Text("No lanes yet. Add a teammate's or the newsroom's lane description (JSON, or a link to it).")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.visibleLanes) { lane in
                Button {
                    composing = .lane(lane)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lane.name).foregroundStyle(.primary)
                        Text("vault \(lane.vault) · key \(lane.fingerprint)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Remove", role: .destructive) { store.remove(lane) }
                    Button("Block") { store.block(LanesStore.laneKey(lane)) }.tint(.orange)
                }
                .contextMenu {
                    Button("Block this lane", systemImage: "hand.raised") { store.block(LanesStore.laneKey(lane)) }
                    Button("Remove", systemImage: "trash", role: .destructive) { store.remove(lane) }
                }
            }
            Button("Add a lane", systemImage: "plus") { addingLane = true }
        } header: {
            Text("Send to a lane")
        } footer: {
            Text("A lane is write-only: what you send is encrypted on this phone to the recipient's key (RSA-OAEP and AES-256-GCM, as sgit), and the server answers only \"ok\".")
        }

        if let message = store.message {
            Section { Text(message).font(.footnote) }
        }
    }

    @Environment(\.openURL) private var openURL

    private func report(kind: String, sender: String, text: String, date: Date?) {
        if let url = LaneReport.mailURL(kind: kind, from: sender, text: text, at: date) { openURL(url) }
    }

    private func blockedLabel(_ key: String) -> String {
        if key.hasPrefix("lane:") {
            let id = String(key.dropFirst(5))
            return "Lane " + (store.lanes.first { $0.id == id }?.name ?? id)
        }
        return "Sender " + key.replacingOccurrences(of: "sender:", with: "")
    }

    @ViewBuilder private var readSections: some View {
        TeamNotesSection()
        Section {
            if let lane = store.myLane {
                LabeledContent("Vault", value: lane.vault)
                LabeledContent("Key", value: lane.fingerprint).font(.caption.monospaced())
                ShareLink(item: (try? lane.descriptor()).map { String(decoding: $0, as: UTF8.self) } ?? "",
                          subject: Text("My PrompTugal lane"), message: Text("Paste this in PrompTugal → Messages → Add a lane.")) {
                    Label("Share my lane description", systemImage: "square.and.arrow.up")
                }
            }
            if let site = store.websiteInbox {
                LabeledContent("Account inbox", value: "vault \(site.vault)")
            } else if CollabHooks.vault?.isOpen ?? false {
                Button("Open my account's inbox", systemImage: "tray") { Task { await store.openWebsiteInbox() } }
            }
            if store.myLane != nil || store.websiteInbox != nil {
                Button(store.working ? "Reading…" : "Check inbox", systemImage: "tray.and.arrow.down") {
                    Task { await store.refreshInbox() }
                }
                .disabled(store.working)
            }
            if let error = store.inboxError { Text(error).font(.footnote).foregroundStyle(.orange) }
            ForEach(store.visibleInbox) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.subject).font(.headline)
                    Text(item.from).font(.caption).foregroundStyle(.secondary)
                    Text(item.body).font(.subheadline).lineLimit(6).textSelection(.enabled)
                    if let at = item.sentAt { Text(at.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
                .contextMenu { ReportBlockMenu(kind: "message", sender: item.from, text: item.text, date: item.sentAt) }
                .accessibilityAction(named: "Report") { report(kind: "message", sender: item.from, text: item.text, date: item.sentAt) }
                .accessibilityAction(named: "Block sender") { store.block(LanesStore.senderKey(item.from)) }
            }
            if !store.inbox.isEmpty {
                Button("Mark all as read") { Task { await store.markRead(store.inbox.map(\.id)) } }
            }
            Button(store.myLane == nil ? "Set up an inbox on this device" : "Inbox settings", systemImage: "gearshape") { showInboxSetup = true }
        } header: {
            Text("My inbox")
        }

        if !store.blocked.isEmpty {
            Section {
                ForEach(store.blocked.sorted(), id: \.self) { key in
                    HStack {
                        Text(blockedLabel(key)).lineLimit(1)
                        Spacer()
                        Button("Unblock") { store.unblock(key) }.buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Blocked")
            } footer: {
                Text("Blocked lanes and senders are hidden on this device. Unblock to see them again.")
            }
        }

        if !store.sent.isEmpty {
            Section("Sent from this device") {
                ForEach(store.sent.prefix(20)) { item in
                    VStack(alignment: .leading) {
                        Text(item.subject).lineLimit(1)
                        Text("\(item.lane) · \(item.at.formatted(date: .omitted, time: .shortened)) · \(item.bytes) B")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }

        if debug {
            Section("Lanes log") {
                if store.log.events.isEmpty { Text("Nothing yet.").foregroundStyle(.secondary) }
                ForEach(store.log.events.prefix(30)) { event in
                    LaneEventRow(event: event)
                }
            }
        }

    }
}

/// Report (prefilled mail) and Block, for a message or note someone else wrote (App Review 1.2).
struct ReportBlockMenu: View {
    let kind: String
    let sender: String
    let text: String
    var date: Date?
    var lanes: LanesStore = .shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Report…", systemImage: "exclamationmark.bubble") {
            if let url = LaneReport.mailURL(kind: kind, from: sender, text: text, at: date) { openURL(url) }
        }
        Button("Block \(sender.isEmpty ? "sender" : sender)", systemImage: "hand.raised", role: .destructive) {
            lanes.block(LanesStore.senderKey(sender))
        }
    }
}

public struct LaneEventRow: View {
    let event: LaneEvent
    public init(event: LaneEvent) { self.event = event }
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(event.kind.rawValue).font(.caption.bold().monospaced())
                if let status = event.status { Text("\(status)").font(.caption.monospaced()) }
                Spacer()
                Text(event.at.formatted(date: .omitted, time: .standard)).font(.caption2).foregroundStyle(.secondary)
            }
            Text(event.lane).font(.caption2).foregroundStyle(.secondary)
            Text(event.detail).font(.caption2.monospaced())
            if event.bytes > 0 || event.durationMs > 0 {
                Text("\(event.bytes) B · \(Int(event.durationMs)) ms").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The Lanes log on its own, for Debug.
struct LanesLogPanel: View {
    var log: LanesLog = .shared
    var body: some View {
        List {
            if log.events.isEmpty { Text("No lane traffic yet.").foregroundStyle(.secondary) }
            ForEach(log.events) { LaneEventRow(event: $0) }
        }
        .navigationTitle("Lanes")
        .toolbar { Button("Clear") { log.clear() } }
    }
}

private struct LaneComposeView: View {
    let store: LanesStore
    let target: LanesView.Compose
    @State private var kind = "note"
    @State private var subject = ""
    @State private var text = ""
    @State private var dictation = SpeechDictation()
    @Environment(\.dismiss) private var dismiss

    private var kinds: [(String, String)] {
        switch target {
        case .newsroom: [("note", "Note"), ("idea", "Idea"), ("fix", "Fix this"), ("wrong", "Wrong"), ("follow-up", "Follow up")]
        case .lane: [("note", "Note"), ("tip", "Tip"), ("message", "Message")]
        }
    }

    var body: some View {
        Form {
            Picker("Kind", selection: $kind) {
                ForEach(kinds.indices, id: \.self) { index in Text(kinds[index].1).tag(kinds[index].0) }
            }
            .pickerStyle(.segmented)
            if case .lane = target {
                TextField("Subject", text: $subject)
            }
            Section {
                TextField("Write, or hold the microphone to talk", text: $text, axis: .vertical)
                    .lineLimit(4...12)
                HStack {
                    Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "mic.circle")
                        .font(.largeTitle)
                        .foregroundStyle(dictation.isRecording ? Color.red : Color.accentColor)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { _ in if !dictation.isRecording { Task { await dictation.start() } } }
                            .onEnded { _ in dictation.stop() })
                        .accessibilityLabel("Hold to dictate")
                    VStack(alignment: .leading) {
                        Text(dictation.isRecording ? "Listening… let go to stop" : "Hold to dictate").font(.subheadline)
                        if dictation.isRecording || !dictation.transcript.isEmpty {
                            Text(dictation.onDevice ? "Transcribed on this device" : "Transcribed by Apple's speech service")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let error = dictation.error { Text(error).font(.footnote).foregroundStyle(.orange) }
            }
            if let page = CollabHooks.currentPage, case .newsroom = target {
                Section("About") { Text(page.title) }
            }
        }
        .onChange(of: dictation.transcript) { _, new in
            if !new.isEmpty { text = new }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dictation.stop(); dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(store.working ? "Sending…" : "Send") {
                    dictation.stop()
                    Task {
                        let ok: Bool
                        switch target {
                        case .newsroom: ok = await store.sendToNewsroom(kind: kind, text: text)
                        case .lane(let lane): ok = await store.send(to: lane, kind: kind, subject: subject, body: text)
                        }
                        if ok { dismiss() }
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.working)
            }
        }
    }

    private var title: String {
        switch target {
        case .newsroom: "To the newsroom"
        case .lane(let lane): "To \(lane.name)"
        }
    }
}

private struct AddLaneView: View {
    let store: LanesStore
    @State private var text = ""
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Name (e.g. Silvio)", text: $name)
                TextField("Lane description JSON, or https:// link", text: $text, axis: .vertical)
                    .lineLimit(3...10)
                    .font(.caption.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Accepts sgit-subscribe/v1 (as sgit.ai/.well-known/sgit-subscribe.json) and the app's own descriptions. The key's fingerprint is checked before it is saved. Everything in a lane description is public: the token can only write.")
            }
            Section {
                Button("Add") {
                    Task {
                        await store.addLane(from: text, name: name)
                        if store.lanes.contains(where: { $0.name == name || name.isEmpty }) { dismiss() }
                    }
                }
                .disabled(text.isEmpty)
                if let message = store.message { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("Add a lane")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}

private struct InboxSetupView: View {
    let store: LanesStore
    @State private var vaultId = ""
    @State private var enumKey = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Vault id", text: $vaultId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(store.myLane == nil ? "Make my inbox key" : "Update") {
                    Task { await store.makeMyLane(vaultId: vaultId.trimmingCharacters(in: .whitespaces)) }
                }
                .disabled(!LaneAddress.isValidVaultId(vaultId.trimmingCharacters(in: .whitespaces)))
            } header: {
                Text("1 · Key")
            } footer: {
                Text("Makes an RSA-4096 key pair in this device's Keychain. The private half never leaves the device; the public half and a new append token go in the description you share.")
            }
            Section {
                Text("Register the lane on your vault once, from a computer with sgit: the SHA-256 of the append token as an append anchor, and the SHA-256 of an enumeration key you choose (POST /api/vault/append/configure, with the vault's write key and an access token). This build does not do that step.")
                    .font(.footnote)
            } header: {
                Text("2 · Register")
            }
            Section {
                SecureField("Enumeration key", text: $enumKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(store.hasEnumKey ? "Replace" : "Save") { store.setEnumKey(enumKey); enumKey = "" }
                    .disabled(enumKey.isEmpty)
            } header: {
                Text("3 · Read")
            } footer: {
                Text("Lets this device list and fetch the lane. Kept in the Keychain, never shown again.")
            }
            if store.myLane != nil {
                Section {
                    Button("Forget my inbox on this device", role: .destructive) { store.forgetMyLane(); dismiss() }
                }
            }
        }
        .navigationTitle("My inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .onAppear { vaultId = store.myLane?.vault ?? vaultId }
    }
}
