import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PTCore

/// Ask: the native AI chat (entry view for `collab.ai`). On iPhone it is a screen or a sheet; on iPad it also
/// opens as a side panel next to any screen with `.askPanel(isPresented:)`.
public struct AskView: View {
    var store: ChatStore = .shared
    /// Shown in the side panel, where the navigation title is not.
    var compact = false

    @State private var showSettings = false
    @FocusState private var composerFocused: Bool
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn

    public init() {}
    init(store: ChatStore, compact: Bool) {
        self.store = store
        self.compact = compact
    }

    public var body: some View {
        @Bindable var store = store
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !store.keys.hasKey {
                        AskKeyCallout { showSettings = true }
                    }
                    if store.consent == .declined {
                        Label("Ask is off: you chose not to send questions to OpenRouter. Change it in Key and settings.", systemImage: "hand.raised")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if store.turns.isEmpty {
                        AskStarters(store: store)
                    }
                    ForEach(store.turns) { turn in
                        AskTurnView(turn: turn, debug: debug)
                            .id(turn.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(maxWidth: 760)                      // a readable line on iPad and in landscape
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.turns.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .safeAreaInset(edge: .bottom) {
                AskComposer(store: store, focused: $composerFocused)
            }
        }
        .navigationTitle(compact ? "" : "Ask")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Model", selection: $store.model) {
                        ForEach(OpenRouter.models) { Text($0.label).tag($0.id) }
                        if !OpenRouter.models.contains(where: { $0.id == store.model }) {
                            Text(store.model).tag(store.model)
                        }
                    }
                    Divider()
                    Button("New conversation", systemImage: "square.and.pencil") { store.clear() }
                        .disabled(store.turns.isEmpty)
                    Button("Key and settings", systemImage: "key") { showSettings = true }
                } label: {
                    Label("Ask settings", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $store.consentRequested) {
            NavigationStack { AskConsentSheet(store: store) }
                .presentationSizing(.form)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { AskSettingsView(store: store) }
                .presentationDetents([.medium, .large])
        }
        .task { await store.refreshPreview() }
    }
}

// MARK: - Pieces

private struct AskKeyCallout: View {
    let open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add your OpenRouter key", systemImage: "key.fill").font(.headline)
            Text("Ask uses your own OpenRouter key. It is kept in this device's Keychain and sent only to openrouter.ai, with each question. You pay OpenRouter for what you ask.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Add key", action: open).buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AskStarters: View {
    let store: ChatStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AskEnvironment.provider.askIntro)
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(AIPrompts.starters(for: AskEnvironment.provider)) { starter in
                Button {
                    starter.run(store)
                } label: {
                    Label(starter.title, systemImage: starter.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!store.keys.hasKey || store.isSending)
            }
        }
    }
}

struct AskTurnView: View {
    let turn: ChatStore.Turn
    let debug: Bool
    /// A link the model wrote, waiting for the person to confirm (S7: links in model output are not opened on one tap).
    @State private var pendingLink: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch turn.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(turn.text)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)
                    .accessibilityLabel("You: \(turn.text)")
            }
        case .tool:
            Label(turn.text, systemImage: "wrench.and.screwdriver")
                .accessibilityLabel("Ask read: \(turn.text)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .error:
            Label(turn.text, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                if turn.text.isEmpty && turn.streaming {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Thinking…").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Text(AIMarkdown.render(turn.text))
                        .environment(\.openURL, OpenURLAction { url in
                            pendingLink = url
                            return .handled
                        })
                        .confirmationDialog("Open this link?", isPresented: Binding(get: { pendingLink != nil },
                                                                                 set: { if !$0 { pendingLink = nil } }),
                                            titleVisibility: .visible, presenting: pendingLink) { url in
                            if AskLinks.canOpen(url) {
                                Button("Open") { openURL(url) }
                            }
                            Button("Copy link") { AskClipboard.copy(url.absoluteString) }
                        } message: { url in
                            Text("The answer links to:\n\(url.absoluteString)\n\nIt was written by the AI model; check it before you open it.")
                        }
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy", systemImage: "doc.on.doc") { AskClipboard.copy(turn.text) }
                            ShareLink(item: turn.text) { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                }
                HStack(spacing: 8) {
                    Text(OpenRouter.label(for: turn.model ?? ""))
                    if let usage = turn.usage, let total = usage.totalTokens { Text("\(total) tokens") }
                    if let cost = turn.usage?.cost { Text(String(format: "$%.4f", cost)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if !turn.mentions.isEmpty {
                    AskMentions(events: turn.mentions)
                }
                if debug, let request = turn.debug, !turn.streaming {
                    AskDebugDisclosure(request: request)
                }
            }
        }
    }
}

/// Sessions named in an answer: pick (star) and open the event page.
struct AskMentions: View {
    let events: [Event]
    private var provider: any AskContextProvider { AskEnvironment.provider }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(events) { event in
                let picked = provider.isPicked(event)
                HStack(spacing: 8) {
                    Button {
                        provider.togglePick(event)
                    } label: {
                        Image(systemName: picked ? "star.fill" : "star")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(picked ? "Remove \(event.title) from my picks" : "Pick \(event.title)")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(.caption.bold()).lineLimit(1)
                        Text("\(Lisbon.dayLabel(event.date)) \(event.time) · \(event.place)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let url = event.url {
                        Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                            .accessibilityLabel("Open \(event.title)")
                    }
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Asked once, before the first question goes out (App Review 5.1.2(i)).
struct AskConsentSheet: View {
    @Bindable var store: ChatStore

    var body: some View {
        Form {
            Section {
                Text("To answer, Ask sends your question and this conversation to **OpenRouter** (openrouter.ai), a service that passes them to **\(OpenRouter.provider(of: store.model))**, the maker of the model you chose (\(OpenRouter.label(for: store.model))). They are sent with your own OpenRouter key; OpenRouter's and the provider's terms apply.")
                Text("Nothing is sent until you allow it. You can change this at any time in Ask → Key and settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                ForEach(AIContextKind.toggleableHere) { kind in
                    Toggle(isOn: Binding(get: { store.isOn(kind) }, set: { on in if on != store.isOn(kind) { store.toggle(kind) } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                            Text(kind.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Also send, with each question")
            } footer: {
                Text("Only what is switched on is sent. The public agenda is on by default; everything else is off.")
            }
            Section {
                Button("Allow") { store.grantConsent() }
                    .bold()
                Button("Don't allow", role: .cancel) { store.declineConsent() }
            }
        }
        .navigationTitle("Send to OpenRouter?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The prompt and the context exactly as sent, for "show the working".
struct AskDebugDisclosure: View {
    let request: ChatStore.RequestDebug

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Model", value: request.model)
                LabeledContent("Messages", value: "\(request.messageCount)")
                LabeledContent("Request", value: ByteCountFormatter.string(fromByteCount: Int64(request.requestBytes), countStyle: .file))
                if let first = request.firstTokenMs { LabeledContent("First text", value: "\(Int(first)) ms") }
                if let total = request.totalMs { LabeledContent("Whole answer", value: "\(Int(total)) ms") }
                if let reason = request.finishReason { LabeledContent("Finish", value: reason) }
                if !request.toolCalls.isEmpty { LabeledContent("Asked for", value: request.toolCalls.joined(separator: ", ")) }
                ForEach(request.parts) { part in
                    LabeledContent(part.kind.title, value: part.body.isEmpty ? "empty, left out" : "\(part.body.count) chars")
                }
                Text("System prompt").font(.caption.bold()).padding(.top, 4)
                Text(request.systemPrompt)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text("The key is sent in one header to openrouter.ai and is not shown here.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .font(.caption)
        } label: {
            Label("How this was asked", systemImage: "ladybug").font(.caption)
        }
    }
}

private struct AskComposer: View {
    @Bindable var store: ChatStore
    var focused: FocusState<Bool>.Binding
    @State private var dictation = SpeechDictation()
    /// Whether dictation runs on this device or at Apple (nil: not known or not available).
    @State private var dictationOnDevice: Bool?

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AIContextKind.toggleableHere) { kind in
                        let on = store.isOn(kind)
                        Button {
                            store.toggle(kind)
                        } label: {
                            Label(chipTitle(kind), systemImage: on ? "checkmark.circle.fill" : kind.symbol)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .tint(on ? Color.accentColor : Color.secondary)
                        .accessibilityValue(on ? "shared with Ask" : "not shared")
                    }
                }
                .padding(.horizontal)
            }
            if let error = dictation.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal)
            }
            if let onDevice = dictationOnDevice {
                Text(onDevice ? "Dictation runs on this device." : "Dictation sends your voice to Apple to turn it into text.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.title)
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.secondary)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !dictation.isRecording { Task { await dictation.start() } } }
                        .onEnded { _ in dictation.stop() })
                    .accessibilityLabel("Hold to dictate")
                    .accessibilityAddTraits(.isButton)
                TextField(dictation.isRecording ? "Listening…" : AskEnvironment.provider.askPlaceholder,
                          text: $store.draft, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
                    .focused(focused)
                    .submitLabel(.send)
                    .onSubmit { store.send() }
                if store.isSending {
                    Button { store.stop() } label: {
                        Image(systemName: "stop.circle.fill").font(.title)
                    }
                    .accessibilityLabel("Stop")
                } else {
                    Button { store.send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }
                    .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.keys.hasKey)
                    .accessibilityLabel("Send")
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
        .onChange(of: dictation.transcript) { _, text in if !text.isEmpty { store.draft = text } }
        .task { dictationOnDevice = SpeechDictation.supportsOnDevice() }
    }

    private func chipTitle(_ kind: AIContextKind) -> String {
        guard let part = store.preview.first(where: { $0.kind == kind }) else { return kind.title }
        return "\(kind.title): \(part.summary)"
    }
}

/// Key entry, vault copy and model. The key field is a `SecureField`; once saved only a masked hint shows.
struct AskSettingsView: View {
    let store: ChatStore
    @State private var entry = ""
    @State private var message: String?
    @State private var working = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        let keys = store.keys
        Form {
            Section {
                if keys.hasKey {
                    LabeledContent("Key", value: keys.hint ?? "saved")
                    Button(working ? "Checking…" : "Check key") {
                        working = true
                        Task {
                            do { message = try await keys.check().summary } catch { message = CollabErrorText.short(error) }
                            working = false
                        }
                    }
                    .disabled(working)
                    Button("Forget key", role: .destructive) { keys.forget(); message = "Key removed from this device." }
                } else {
                    SecureField("sk-or-…", text: $entry)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                    if !entry.isEmpty && !OpenRouter.looksLikeOpenRouterKey(entry) {
                        Text("OpenRouter keys usually start with sk-or-.").font(.caption).foregroundStyle(.orange)
                    }
                    Button("Save key") {
                        do { try keys.save(entry); entry = ""; message = "Saved in the Keychain on this device." }
                        catch { message = CollabErrorText.short(error) }
                    }
                    .disabled(entry.isEmpty)
                    Link("Get a key at openrouter.ai/keys", destination: URL(string: "https://openrouter.ai/keys")!)
                }
            } header: {
                Text("OpenRouter key")
            } footer: {
                Text("Kept in this device's Keychain, never synced, sent only to openrouter.ai. Not in logs or debug panels.")
            }

            Section {
                Button("Save key to my vault") { Task { await vault(save: true) } }
                    .disabled(!keys.hasKey || !(CollabHooks.vault?.canWrite ?? false) || working)
                Button("Take key from my vault") { Task { await vault(save: false) } }
                    .disabled(!(CollabHooks.vault?.isOpen ?? false) || working)
                if let at = keys.savedToVaultAt {
                    LabeledContent("Saved to vault", value: at.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Vault")
            } footer: {
                Text(CollabHooks.vault == nil
                     ? "Vault copies need the vault on this build. The file is \(AIKeyStore.vaultPath), encrypted in your vault."
                     : "Writes \(AIKeyStore.vaultPath), encrypted in your vault, so your other devices can take it.")
            }

            Section {
                Toggle("Keep this conversation on this device", isOn: $store.keepConversation)
            } footer: {
                Text("Off by default. Keeps only the words of the conversation, in a file locked with the device; never the key or the data sent as context. Turning it off deletes the file.")
            }

            Section {
                Toggle("Let Ask read the app's data with tools", isOn: $store.useTools)
            } footer: {
                Text("Read-only: search the agenda, my picks, team status, my agents, teammates' plans. Each call shows in the conversation.")
            }

            Section {
                switch store.consent {
                case .granted:
                    LabeledContent("Sending to OpenRouter", value: "Allowed")
                    Button("Withdraw permission", role: .destructive) { store.revokeConsent() }
                case .declined:
                    LabeledContent("Sending to OpenRouter", value: "Not allowed")
                    Button("Ask me again") { store.revokeConsent() }
                case .unknown:
                    LabeledContent("Sending to OpenRouter", value: "Not asked yet")
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("Ask sends your question, the conversation and the data you share below to OpenRouter (openrouter.ai), which passes them to \(OpenRouter.provider(of: store.model)) to answer.")
            }

            Section {
                ForEach(AIContextKind.toggleableHere) { kind in
                    Toggle(isOn: Binding(get: { store.isOn(kind) }, set: { on in if on != store.isOn(kind) { store.toggle(kind) } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                            Text(kind.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("What Ask may send")
            } footer: {
                Text("Off unless you switch it on, except the public agenda. Teammates' plans and the current page each need their own switch.")
            }

            Section("Model") {
                Picker("Model", selection: $store.model) {
                    ForEach(OpenRouter.models) { Text($0.label).tag($0.id) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("Ask settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private func vault(save: Bool) async {
        working = true
        defer { working = false }
        do {
            if save {
                try await store.keys.saveToVault(model: store.model)
                message = "Saved to \(AIKeyStore.vaultPath) in your vault."
            } else if let model = try await store.keys.loadFromVault() {
                store.model = model
                message = "Key taken from your vault."
            } else {
                message = store.keys.hasKey ? "Key taken from your vault." : "Your vault has no saved key."
            }
        } catch {
            message = CollabErrorText.short(error)
        }
    }
}

// MARK: - iPad side panel

extension View {
    /// Ask as a side panel (iPad, regular width) or a sheet (iPhone), next to whatever this view shows.
    func askPanel(isPresented: Binding<Bool>, store: ChatStore = .shared) -> some View {
        inspector(isPresented: isPresented) {
            NavigationStack {
                AskView(store: store, compact: true)
                    .navigationTitle("Ask")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .inspectorColumnWidth(min: 320, ideal: 400, max: 560)
            .presentationDetents([.medium, .large])
        }
    }
}

extension View {
    /// Ask next to any screen, in one line: a toolbar button and ⌘K open it as a side panel on iPad (regular
    /// width) and as a sheet on iPhone. For the shell's detail view, e.g.
    /// `destination.view().askAnywhere(enabled: destination.id != "collab.ai")`.
    public func askAnywhere(enabled: Bool = true) -> some View {
        modifier(AskAnywhere(enabled: enabled))
    }
}

private struct AskAnywhere: ViewModifier {
    let enabled: Bool
    @State private var open = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .toolbar { ToolbarItem(placement: .primaryAction) { AskPanelButton(isPresented: $open) } }
                .askPanel(isPresented: $open)
        } else {
            content
        }
    }
}

/// A toolbar button that opens the Ask panel. `AskPanelButton(isPresented: $askOpen)`.
struct AskPanelButton: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Ask", systemImage: "sparkles")
        }
        .keyboardShortcut("k", modifiers: [.command])
    }
}

/// Copies text to this device only (not Handoff's universal clipboard), cleared after two minutes (S7).
enum AskClipboard {
    static let lifetime: TimeInterval = 120

    static func copy(_ text: String, pasteboard: UIPasteboard = .general) {
        pasteboard.setItems([[UTType.plainText.identifier: text]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)])
    }
}

/// Which links from model output may be opened at all (after confirmation): web pages and mail only.
enum AskLinks {
    static func canOpen(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "mailto" { return true }
        return scheme == "https" && url.host() != nil && url.user == nil && url.password == nil
    }
}

/// Light Markdown for answers (bold, italics, code, links); falls back to plain text.
enum AIMarkdown {
    static func render(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// The last Ask requests as sent, for Debug → Collaboration and AI (the Team app's panel shows it).
public struct AskRequestsDebugRows: View {
    var chat: ChatStore = .shared

    public init() {}

    public var body: some View {
        let requests = chat.turns.compactMap(\.debug)
        if requests.isEmpty { Text("No question asked yet.").foregroundStyle(.secondary) }
        ForEach(Array(requests.enumerated().reversed()), id: \.offset) { _, request in
            AskDebugDisclosure(request: request)
        }
    }
}
