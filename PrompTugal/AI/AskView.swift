import SwiftUI

/// Ask: the native AI chat (entry view for `collab.ai`). On iPhone it is a screen or a sheet; on iPad it also
/// opens as a side panel next to any screen with `.askPanel(isPresented:)`.
struct AskView: View {
    var store: ChatStore = .shared
    /// Shown in the side panel, where the navigation title is not.
    var compact = false

    @State private var showSettings = false
    @FocusState private var composerFocused: Bool
    @AppStorage("debug.enabled") private var debug = true

    var body: some View {
        @Bindable var store = store
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !store.keys.hasKey {
                        AskKeyCallout { showSettings = true }
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
            Text("Ask about the summit, your day and the team. Choose below what Ask may see.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(AIPrompts.starters) { starter in
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

    var body: some View {
        switch turn.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(turn.text)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)
            }
        case .error:
            Label(turn.text, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                if turn.text.isEmpty && turn.streaming {
                    ProgressView().controlSize(.small)
                } else {
                    Text(AIMarkdown.render(turn.text))
                        .textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    Text(OpenRouter.label(for: turn.model ?? ""))
                    if let usage = turn.usage, let total = usage.totalTokens { Text("\(total) tokens") }
                    if let cost = turn.usage?.cost { Text(String(format: "$%.4f", cost)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if debug, let request = turn.debug, !turn.streaming {
                    AskDebugDisclosure(request: request)
                }
            }
        }
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

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AIContextKind.toggleable) { kind in
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
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about today, your picks, the team…", text: $store.draft, axis: .vertical)
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
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
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
                        catch { message = error.localizedDescription }
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
            message = error.localizedDescription
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

/// Light Markdown for answers (bold, italics, code, links); falls back to plain text.
enum AIMarkdown {
    static func render(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
