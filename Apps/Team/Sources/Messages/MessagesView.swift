import PTCore
import PTLanes
import SwiftUI
import UIKit
import UserNotifications

/// Team messaging v1 (WS-203): chats and email between people and agents, sealed end to end over the team's vaults.
/// The formats and the crypto are PTLanes/Messages; this file is the screens. Plan: web-summit.sgit.ai/messaging/.

/// One store per person on this device, kept for the app's life, so polling and unread counts survive navigation.
@MainActor
enum MessagesHub {
    private static var stores: [String: MessageStore] = [:]

    static func store(for person: String) -> MessageStore {
        if let s = stores[person] { return s }
        let s = MessageStore.forDevice(person: person)
        s.onNew = { notify($0, me: person) }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        stores[person] = s
        return s
    }

    /// A local notification per new message: the sender's name, then the first line. No emoji, no greeting.
    static func notify(_ messages: [TeamMessage], me: String) {
        for m in messages where m.from != me {
            let content = UNMutableNotificationContent()
            content.title = displayName(m.from)
            content.body = m.preview
            content.threadIdentifier = m.thread
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "msg-" + m.id, content: content, trigger: nil))
        }
    }

    static func displayName(_ name: String) -> String {
        if name.contains("@") { return name.hasPrefix("conductor@") ? "Your conductor" : String(name.split(separator: "@").first ?? "") }
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

struct MessagesView: View {
    @Environment(TeamIdentityStore.self) private var identity

    var body: some View {
        if let me = identity.current?.id {
            MessagesScreen(store: MessagesHub.store(for: me))
        } else {
            ContentUnavailableView("Choose who you are", systemImage: "person.crop.circle.badge.questionmark",
                                   description: Text("Messages are sealed to you. Pick your name on the Team screen first."))
        }
    }
}

private struct MessagesScreen: View {
    @ObservedObject var store: MessageStore
    @State private var mode = 0
    @State private var composing = false
    @State private var newChat = false

    var body: some View {
        List {
            Section {
                StatusLine(store: store)
                Picker("Show", selection: $mode) {
                    Text(label("Chats", store.threads.filter { !$0.isEmail }.reduce(0) { $0 + $1.unread })).tag(0)
                    Text(label("Email", store.threads.filter(\.isEmail).reduce(0) { $0 + $1.unread })).tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            Section {
                let rows = store.threads.filter { ($0.isEmail ? 1 : 0) == mode }
                if rows.isEmpty {
                    Text(mode == 0 ? "No chats yet. Start one with New." : "No email yet.")
                        .font(Typo.meta).foregroundStyle(Palette.muted)
                }
                ForEach(rows) { t in
                    NavigationLink {
                        if t.isEmail { EmailThreadView(store: store, thread: t.id) } else { ChatThreadView(store: store, thread: t.id, title: t.title) }
                    } label: { ThreadRow(summary: t, me: store.me) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { if mode == 0 { newChat = true } else { composing = true } } label: {
                    Label(mode == 0 ? "New chat" : "Write", systemImage: mode == 0 ? "square.and.pencil" : "envelope")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink { DeviceKeyView(store: store) } label: { Label("This iPhone's key", systemImage: "key") }
            }
        }
        .sheet(isPresented: $newChat) { NewChatSheet(store: store) }
        .sheet(isPresented: $composing) { ComposeEmailView(store: store) }
        .refreshable { await store.poll() }
        .onAppear { store.setPace(.screenOpen) }
        .onDisappear { store.setPace(.appOpen) }
    }

    func label(_ s: String, _ n: Int) -> String { n > 0 ? "\(s) · \(n)" : s }
}

private struct StatusLine: View {
    @ObservedObject var store: MessageStore
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            switch store.status {
            case .notSwitchedOn(let why):
                Label(why, systemImage: "hourglass").foregroundStyle(Palette.amber)
            case .offline(let why):
                Label("Not connected: \(why)", systemImage: "wifi.slash").foregroundStyle(Palette.muted)
            case .sending:
                Label("Sending…", systemImage: "arrow.up.circle").foregroundStyle(Palette.muted)
            case .upToDate(let at):
                Label("Up to date · \(at.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle").foregroundStyle(Palette.green)
            }
            if store.refusedCount > 0 {
                Label("\(store.refusedCount) message\(store.refusedCount == 1 ? "" : "s") could not be verified and \(store.refusedCount == 1 ? "was" : "were") not shown",
                      systemImage: "exclamationmark.shield").foregroundStyle(Palette.red)
            }
        }
        .font(Typo.meta)
    }
}

private struct ThreadRow: View {
    let summary: MessageThreadSummary
    let me: String
    var body: some View {
        HStack(spacing: Space.m) {
            Avatar(name: summary.title, group: summary.isGroup)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(MessagesHub.displayName(summary.title)).font(.body.weight(.semibold)).lineLimit(1)
                    if summary.title.contains("@") { AgentTag() }
                    Spacer()
                    Text(Self.time(summary.last.at)).font(Typo.meta).foregroundStyle(Palette.muted)
                }
                Text((summary.last.from == me ? "You: " : "") + summary.last.preview)
                    .font(.subheadline).foregroundStyle(Palette.muted).lineLimit(1)
            }
            if summary.unread > 0 {
                Text("\(summary.unread)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Palette.red, in: Capsule())
                    .accessibilityLabel("\(summary.unread) unread")
            }
        }
        .padding(.vertical, 2)
    }

    static func time(_ iso: String) -> String {
        guard let d = MessageTime.date(iso) else { return "" }
        return Calendar.current.isDateInToday(d) ? d.formatted(date: .omitted, time: .shortened) : d.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct Avatar: View {
    let name: String
    var group = false
    var body: some View {
        let agent = name.contains("@")
        Text(agent ? "AI" : String(MessagesHub.displayName(name).prefix(1)))
            .font(.subheadline.weight(.bold))
            .foregroundStyle(agent ? Palette.ink : .white)
            .frame(width: 40, height: 40)
            .background(agent ? Palette.paper2 : (group ? Palette.muted : Color(red: 0.91, green: 0.73, blue: 0.25)), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct AgentTag: View {
    var body: some View {
        Text("AI").font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 5).padding(.vertical, 1).background(Palette.paper2, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("AI helper")
    }
}

// MARK: A chat

private struct ChatThreadView: View {
    @ObservedObject var store: MessageStore
    let thread: String
    let title: String
    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        let list = store.messages(in: thread)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Space.xs) {
                    Text("Sealed end to end. Only the people in this chat can read it.")
                        .font(Typo.meta).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        .padding(Space.s).frame(maxWidth: .infinity).background(Palette.paper2, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, Space.s)
                    ForEach(list) { m in
                        Bubble(message: m, mine: m.from == store.me, showName: thread.hasPrefix("group:")).id(m.id)
                    }
                    if let last = list.last, last.from == store.me {
                        Text("Sent").font(.caption2).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(Space.l)
            }
            .onChange(of: list.count) { _, _ in if let id = list.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
            .onAppear { if let id = list.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
        }
        .background(Palette.paper)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.xs) {
                if let error { Text(error).font(Typo.meta).foregroundStyle(Palette.red) }
                HStack(spacing: Space.s) {
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...5).padding(.horizontal, Space.m).padding(.vertical, Space.s)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").font(.body.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Palette.red, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send")
                }
            }
            .padding(Space.m).background(.bar)
        }
        .navigationTitle(MessagesHub.displayName(title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markRead(thread); store.setPace(.screenOpen) }
        .onChange(of: list.count) { _, _ in store.markRead(thread) }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let others = store.messages(in: thread).last.map { ($0.to + [$0.from]).filter { $0 != store.me } } ?? []
        do {
            if thread.hasPrefix("group:") {
                let g = String(thread.dropFirst("group:".count))
                try await store.send(text: text, to: store.directory?.groups[g] ?? others, group: g)
            } else {
                try await store.send(text: text, to: Array(Set(others)))
            }
            draft = ""; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct Bubble: View {
    let message: TeamMessage
    let mine: Bool
    let showName: Bool
    var body: some View {
        HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 2) {
                if showName && !mine { Text(MessagesHub.displayName(message.from)).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted) }
                Text(text).font(.body)
                Text(ThreadRow.time(message.at)).font(.caption2).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, Space.m).padding(.vertical, Space.s)
            .background(mine ? Palette.red.opacity(0.12) : Palette.card, in: RoundedRectangle(cornerRadius: 18))
            if !mine { Spacer(minLength: 48) }
        }
    }
    var text: String {
        switch message {
        case .chat(let c): c.text
        case .email(let e): e.card.subject + "\n" + e.body
        }
    }
}

// MARK: Email

private struct EmailThreadView: View {
    @ObservedObject var store: MessageStore
    let thread: String
    @State private var replying: EmailMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ForEach(store.messages(in: thread)) { m in
                    if case .email(let e) = m {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text(e.card.subject).font(Typo.title)
                            HStack {
                                Text(MessagesHub.displayName(e.from)).font(.subheadline.weight(.semibold))
                                if e.from.contains("@") { AgentTag() }
                                Spacer()
                                Text(ThreadRow.time(e.at)).font(Typo.meta).foregroundStyle(Palette.muted)
                            }
                            Text(e.body).font(.body).textSelection(.enabled)
                                .padding(Space.l).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
                            HStack {
                                Button("Reply") { replying = e }.buttonStyle(.borderedProminent).tint(Palette.red)
                            }
                        }
                    }
                }
            }
            .padding(Space.l)
        }
        .background(Palette.paper)
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markRead(thread) }
        .sheet(item: $replying) { e in
            ComposeEmailView(store: store, to: e.from == store.me ? e.to.joined(separator: ", ") : e.from,
                             subject: e.card.subject.hasPrefix("Re: ") ? e.card.subject : "Re: " + e.card.subject, thread: e.thread, replyTo: e.id)
        }
    }
}

struct ComposeEmailView: View {
    @ObservedObject var store: MessageStore
    @State var to = ""
    @State var subject = ""
    var thread: String?
    var replyTo: String?
    @State private var text = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(store: MessageStore, to: String = "", subject: String = "", thread: String? = nil, replyTo: String? = nil) {
        self.store = store
        _to = State(initialValue: to)
        _subject = State(initialValue: subject)
        self.thread = thread
        self.replyTo = replyTo
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("To: a person, an agent or several, with commas", text: $to).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Subject", text: $subject)
                TextField("Write your email", text: $text, axis: .vertical).lineLimit(6...20)
                if let error { Text(error).foregroundStyle(Palette.red) }
                Text("Sealed to each reader and signed by this iPhone.").font(Typo.meta).foregroundStyle(Palette.muted)
            }
            .navigationTitle(replyTo == nil ? "New email" : "Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }.disabled(to.isEmpty || subject.isEmpty || text.isEmpty)
                }
            }
        }
    }

    func send() async {
        let names = to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        do {
            try await store.sendEmail(subject: subject, text: text, to: names, thread: thread, replyTo: replyTo)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: New chat

private struct NewChatSheet: View {
    @ObservedObject var store: MessageStore
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if store.directory == nil { ProgressView("Loading the team's keys…") }
                if let error { Text(error).foregroundStyle(Palette.red) }
                if let groups = store.directory?.groups, !groups.isEmpty {
                    Section("Groups") {
                        ForEach(groups.keys.sorted(), id: \.self) { g in
                            row(title: "The " + g, thread: MessageThread.group(g), group: true)
                        }
                    }
                }
                Section("People") {
                    ForEach((store.directory?.names ?? []).filter { !$0.contains("@") && $0 != store.me }, id: \.self) { n in
                        row(title: n, thread: MessageThread.direct([store.me, n]), group: false)
                    }
                }
                Section("Agents") {
                    ForEach((store.directory?.names ?? []).filter { $0.contains("@") && $0.hasSuffix("." + store.me) }, id: \.self) { n in
                        row(title: n, thread: MessageThread.direct([store.me, n]), group: false)
                    }
                }
            }
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { if store.directory == nil { await store.refreshDirectory() } }
        }
    }

    func row(title: String, thread: String, group: Bool) -> some View {
        NavigationLink {
            NewThreadView(store: store, thread: thread, title: title, group: group)
        } label: {
            HStack(spacing: Space.m) {
                Avatar(name: title, group: group)
                Text(MessagesHub.displayName(title))
                if title.contains("@") { AgentTag() }
            }
        }
    }
}

/// A first message to someone: the same composer, with the recipients known up front.
private struct NewThreadView: View {
    @ObservedObject var store: MessageStore
    let thread: String
    let title: String
    let group: Bool
    @State private var draft = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Sealed end to end. Only the people in this chat can read it.").font(Typo.meta).foregroundStyle(Palette.muted)
            TextField("Message", text: $draft, axis: .vertical).lineLimit(3...8)
                .padding(Space.m).background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
            if let error { Text(error).font(Typo.meta).foregroundStyle(Palette.red) }
            Button("Send") { Task { await send() } }.buttonStyle(.borderedProminent).tint(Palette.red)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding(Space.l)
        .background(Palette.paper)
        .navigationTitle(MessagesHub.displayName(title))
    }

    func send() async {
        do {
            if group {
                let g = String(thread.dropFirst("group:".count))
                try await store.send(text: draft, to: store.directory?.groups[g] ?? [], group: g)
            } else {
                try await store.send(text: draft, to: [title])
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: This iPhone's key, and switching messaging on

struct DeviceKeyView: View {
    @ObservedObject var store: MessageStore
    @State private var entry = ""
    @State private var vaultText = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("This iPhone has its own messaging key, made in its secure chip. It never leaves the phone. Send the public half below to your conductor, who adds it to the team's list of device keys, so people can write to this phone.")
                    .font(.subheadline)
                Text(entry.isEmpty ? "…" : entry).font(Typo.dataSmall).textSelection(.enabled)
                ShareLink(item: entry) { Label("Send the public key", systemImage: "square.and.arrow.up") }.disabled(entry.isEmpty)
            } header: { Text("This iPhone's key") }
            Section {
                Text("When the team's messaging vault is ready, your conductor sends you its details. Paste them here to switch messaging on.")
                    .font(.subheadline)
                TextField("The messaging vault's details (JSON)", text: $vaultText, axis: .vertical).lineLimit(3...8)
                    .font(Typo.dataSmall).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Switch messaging on") {
                    do {
                        try store.useVault(try MessagingVaultConfig.parse(vaultText))
                        message = "Messaging is on. Checking for messages."
                        Task { await store.poll() }
                    } catch { message = "Those details could not be read: \(error.localizedDescription)" }
                }
                .disabled(vaultText.isEmpty)
                if let message { Text(message).font(Typo.meta).foregroundStyle(Palette.muted) }
            } header: { Text("Switch messaging on") }
        }
        .navigationTitle("This iPhone's key")
        .task {
            let device = UIDevice.current.name
            entry = (try? MessagingDevice.publicEntry(person: store.me, device: device)) ?? "The key could not be made on this device."
        }
    }
}
