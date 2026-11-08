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
        .navigationTitle(compact ? "" : String(localized: "Ask", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(String(localized: "Model", bundle: .module), selection: $store.model) {
                        ForEach(OpenRouter.models) { Text($0.label).tag($0.id) }
                        if !OpenRouter.models.contains(where: { $0.id == store.model }) {
                            Text(store.model).tag(store.model)
                        }
                    }
                    Divider()
                    Button(String(localized: "New conversation", bundle: .module), systemImage: "square.and.pencil") { store.clear() }
                        .disabled(store.turns.isEmpty)
                    Button(String(localized: "Key and settings", bundle: .module), systemImage: "key") { showSettings = true }
                } label: {
                    Label(String(localized: "Ask settings", bundle: .module), systemImage: "ellipsis.circle")
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
            Label(String(localized: "Add your OpenRouter key", bundle: .module), systemImage: "key.fill").font(.headline)
            Text(String(localized: "Ask uses your own OpenRouter key. It is kept in this device's Keychain and sent only to openrouter.ai, with each question. You pay OpenRouter for what you ask.", bundle: .module))
                .font(.subheadline).foregroundStyle(.secondary)
            Button(String(localized: "Add key", bundle: .module), action: open).buttonStyle(.borderedProminent)
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
            Text(String(localized: "Ask about the summit, your day and the team. Choose below what Ask may see.", bundle: .module))
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
                    .accessibilityLabel(String(localized: "You: \(turn.text)", bundle: .module))
            }
        case .tool:
            Label(turn.text, systemImage: "wrench.and.screwdriver")
                .accessibilityLabel(String(localized: "Ask read: \(turn.text)", bundle: .module))
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
                        Text(String(localized: "Thinking…", bundle: .module)).font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Text(AIMarkdown.render(turn.text))
                        .environment(\.openURL, OpenURLAction { url in
                            pendingLink = url
                            return .handled
                        })
                        .confirmationDialog(String(localized: "Open this link?", bundle: .module), isPresented: Binding(get: { pendingLink != nil },
                                                                                 set: { if !$0 { pendingLink = nil } }),
                                            titleVisibility: .visible, presenting: pendingLink) { url in
                            if AskLinks.canOpen(url) {
                                Button(String(localized: "Open", bundle: .module)) { openURL(url) }
                            }
                            Button(String(localized: "Copy link", bundle: .module)) { AskClipboard.copy(url.absoluteString) }
                        } message: { url in
                            Text(String(localized: "The answer links to:\n\(url.absoluteString)\n\nIt was written by the AI model; check it before you open it.", bundle: .module))
                        }
                        .textSelection(.enabled)
                        .contextMenu {
                            Button(String(localized: "Copy", bundle: .module), systemImage: "doc.on.doc") { AskClipboard.copy(turn.text) }
                            ShareLink(item: turn.text) { Label(String(localized: "Share", bundle: .module), systemImage: "square.and.arrow.up") }
                        }
                }
                HStack(spacing: 8) {
                    Text(OpenRouter.label(for: turn.model ?? ""))
                    if let usage = turn.usage, let total = usage.totalTokens { Text(String(localized: "\(total) tokens", bundle: .module)) }
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
                    .accessibilityLabel(picked ? String(localized: "Remove \(event.title) from my picks", bundle: .module) : String(localized: "Pick \(event.title)", bundle: .module))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(.caption.bold()).lineLimit(1)
                        Text("\(Lisbon.dayLabel(event.date)) \(event.time) · \(event.place)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let url = event.url {
                        Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                            .accessibilityLabel(String(localized: "Open \(event.title)", bundle: .module))
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
                Text(String(localized: "To answer, Ask sends your question and this conversation to **OpenRouter** (openrouter.ai), a service that passes them to **\(OpenRouter.provider(of: store.model))**, the maker of the model you chose (\(OpenRouter.label(for: store.model))). They are sent with your own OpenRouter key; OpenRouter's and the provider's terms apply.", bundle: .module))
                Text(String(localized: "Nothing is sent until you allow it. You can change this at any time in Ask → Key and settings.", bundle: .module))
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
                Text(String(localized: "Also send, with each question", bundle: .module))
            } footer: {
                Text(String(localized: "Only what is switched on is sent. The public agenda is on by default; everything else is off.", bundle: .module))
            }
            Section {
                Button(String(localized: "Allow", bundle: .module)) { store.grantConsent() }
                    .bold()
                Button(String(localized: "Don't allow", bundle: .module), role: .cancel) { store.declineConsent() }
            }
        }
        .navigationTitle(String(localized: "Send to OpenRouter?", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The prompt and the context exactly as sent, for "show the working".
struct AskDebugDisclosure: View {
    let request: ChatStore.RequestDebug

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent(String(localized: "Model", bundle: .module), value: request.model)
                LabeledContent("Messages", value: "\(request.messageCount)")
                LabeledContent("Request", value: ByteCountFormatter.string(fromByteCount: Int64(request.requestBytes), countStyle: .file))
                if let first = request.firstTokenMs { LabeledContent(String(localized: "First text", bundle: .module), value: "\(Int(first)) ms") }
                if let total = request.totalMs { LabeledContent(String(localized: "Whole answer", bundle: .module), value: "\(Int(total)) ms") }
                if let reason = request.finishReason { LabeledContent("Finish", value: reason) }
                if !request.toolCalls.isEmpty { LabeledContent(String(localized: "Asked for", bundle: .module), value: request.toolCalls.joined(separator: ", ")) }
                ForEach(request.parts) { part in
                    LabeledContent(part.kind.title, value: part.body.isEmpty ? "empty, left out" : "\(part.body.count) chars")
                }
                Text(String(localized: "System prompt", bundle: .module)).font(.caption.bold()).padding(.top, 4)
                Text(request.systemPrompt)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text(String(localized: "The key is sent in one header to openrouter.ai and is not shown here.", bundle: .module))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .font(.caption)
        } label: {
            Label(String(localized: "How this was asked", bundle: .module), systemImage: "ladybug").font(.caption)
        }
    }
}

private struct AskComposer: View {
    @Bindable var store: ChatStore
    var focused: FocusState<Bool>.Binding
    @State private var dictation = SpeechDictation()

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
                        .accessibilityValue(on ? String(localized: "shared with Ask", bundle: .module) : String(localized: "not shared", bundle: .module))
                    }
                }
                .padding(.horizontal)
            }
            if let error = dictation.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.title)
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.secondary)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !dictation.isRecording { Task { await dictation.start() } } }
                        .onEnded { _ in dictation.stop() })
                    .accessibilityLabel(String(localized: "Hold to dictate", bundle: .module))
                    .accessibilityAddTraits(.isButton)
                TextField(dictation.isRecording ? String(localized: "Listening…", bundle: .module) : String(localized: "Ask about today, your picks, the team…", bundle: .module),
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
                    .accessibilityLabel(String(localized: "Stop", bundle: .module))
                } else {
                    Button { store.send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }
                    .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.keys.hasKey)
                    .accessibilityLabel(String(localized: "Send", bundle: .module))
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
        .onChange(of: dictation.transcript) { _, text in if !text.isEmpty { store.draft = text } }
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
                    Button(working ? String(localized: "Checking…", bundle: .module) : String(localized: "Check key", bundle: .module)) {
                        working = true
                        Task {
                            do { message = try await keys.check().summary } catch { message = CollabErrorText.short(error) }
                            working = false
                        }
                    }
                    .disabled(working)
                    Button(String(localized: "Forget key", bundle: .module), role: .destructive) { keys.forget(); message = String(localized: "Key removed from this device.", bundle: .module) }
                } else {
                    SecureField("sk-or-…", text: $entry)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                    if !entry.isEmpty && !OpenRouter.looksLikeOpenRouterKey(entry) {
                        Text(String(localized: "OpenRouter keys usually start with sk-or-.", bundle: .module)).font(.caption).foregroundStyle(.orange)
                    }
                    Button(String(localized: "Save key", bundle: .module)) {
                        do { try keys.save(entry); entry = ""; message = String(localized: "Saved in the Keychain on this device.", bundle: .module) }
                        catch { message = CollabErrorText.short(error) }
                    }
                    .disabled(entry.isEmpty)
                    Link(String(localized: "Get a key at openrouter.ai/keys", bundle: .module), destination: URL(string: "https://openrouter.ai/keys")!)
                }
            } header: {
                Text(String(localized: "OpenRouter key", bundle: .module))
            } footer: {
                Text(String(localized: "Kept in this device's Keychain, never synced, sent only to openrouter.ai. Not in logs or debug panels.", bundle: .module))
            }

            Section {
                Button(String(localized: "Save key to my vault", bundle: .module)) { Task { await vault(save: true) } }
                    .disabled(!keys.hasKey || !(CollabHooks.vault?.canWrite ?? false) || working)
                Button(String(localized: "Take key from my vault", bundle: .module)) { Task { await vault(save: false) } }
                    .disabled(!(CollabHooks.vault?.isOpen ?? false) || working)
                if let at = keys.savedToVaultAt {
                    LabeledContent(String(localized: "Saved to vault", bundle: .module), value: at.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text(String(localized: "Vault", bundle: .module))
            } footer: {
                Text(CollabHooks.vault == nil
                     ? String(localized: "Vault copies need the vault on this build. The file is \(AIKeyStore.vaultPath), encrypted in your vault.", bundle: .module)
                     : String(localized: "Writes \(AIKeyStore.vaultPath), encrypted in your vault, so your other devices can take it.", bundle: .module))
            }

            Section {
                Toggle(String(localized: "Keep this conversation on this device", bundle: .module), isOn: $store.keepConversation)
            } footer: {
                Text(String(localized: "Off by default. Keeps only the words of the conversation, in a file locked with the device; never the key or the data sent as context. Turning it off deletes the file.", bundle: .module))
            }

            Section {
                Toggle(String(localized: "Let Ask read the app's data with tools", bundle: .module), isOn: $store.useTools)
            } footer: {
                Text(String(localized: "Read-only: search the agenda, my picks, team status, my agents, teammates' plans. Each call shows in the conversation.", bundle: .module))
            }

            Section {
                switch store.consent {
                case .granted:
                    LabeledContent(String(localized: "Sending to OpenRouter", bundle: .module), value: String(localized: "Allowed", bundle: .module))
                    Button(String(localized: "Withdraw permission", bundle: .module), role: .destructive) { store.revokeConsent() }
                case .declined:
                    LabeledContent(String(localized: "Sending to OpenRouter", bundle: .module), value: String(localized: "Not allowed", bundle: .module))
                    Button(String(localized: "Ask me again", bundle: .module)) { store.revokeConsent() }
                case .unknown:
                    LabeledContent(String(localized: "Sending to OpenRouter", bundle: .module), value: String(localized: "Not asked yet", bundle: .module))
                }
            } header: {
                Text(String(localized: "Permission", bundle: .module))
            } footer: {
                Text(String(localized: "Ask sends your question, the conversation and the data you share below to OpenRouter (openrouter.ai), which passes them to \(OpenRouter.provider(of: store.model)) to answer.", bundle: .module))
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
                Text(String(localized: "What Ask may send", bundle: .module))
            } footer: {
                Text(String(localized: "Off unless you switch it on, except the public agenda. Teammates' plans and the current page each need their own switch.", bundle: .module))
            }

            Section(String(localized: "Model", bundle: .module)) {
                Picker(String(localized: "Model", bundle: .module), selection: $store.model) {
                    ForEach(OpenRouter.models) { Text($0.label).tag($0.id) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle(String(localized: "Ask settings", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Done", bundle: .module)) { dismiss() } } }
    }

    private func vault(save: Bool) async {
        working = true
        defer { working = false }
        do {
            if save {
                try await store.keys.saveToVault(model: store.model)
                message = String(localized: "Saved to \(AIKeyStore.vaultPath) in your vault.", bundle: .module)
            } else if let model = try await store.keys.loadFromVault() {
                store.model = model
                message = String(localized: "Key taken from your vault.", bundle: .module)
            } else {
                message = store.keys.hasKey ? String(localized: "Key taken from your vault.", bundle: .module) : String(localized: "Your vault has no saved key.", bundle: .module)
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
                    .navigationTitle(String(localized: "Ask", bundle: .module))
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
            Label(String(localized: "Ask", bundle: .module), systemImage: "sparkles")
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
