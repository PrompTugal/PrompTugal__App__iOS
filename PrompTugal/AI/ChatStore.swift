import Foundation
import Observation

/// One conversation with Ask. Lives for the app's run; nothing is saved to disk (as on the website, where the
/// conversation stays in the tab).
@MainActor @Observable
final class ChatStore {
    static let shared = ChatStore()

    struct Turn: Identifiable, Equatable {
        enum Role: Equatable {
            case user, assistant, error, tool
            var name: String {
                switch self {
                case .user: return "user"
                case .assistant: return "assistant"
                case .error: return "error"
                case .tool: return "tool"
                }
            }
        }
        let id = UUID()
        let role: Role
        var text: String
        var model: String?
        var usage: StreamUsage?
        var debug: RequestDebug?
        var streaming = false
        /// Agenda sessions the answer names, for pick and open buttons under it.
        var mentions: [Event] = []
    }

    /// What went to OpenRouter for one answer, shown in the turn's debug disclosure. Never the key.
    struct RequestDebug: Equatable {
        let model: String
        let systemPrompt: String
        let parts: [AIContextPart]
        let messageCount: Int
        let requestBytes: Int
        let sentAt: Date
        var firstTokenMs: Double?
        var totalMs: Double?
        var finishReason: String?
        var toolCalls: [String] = []
    }

    private(set) var turns: [Turn] = []
    private(set) var isSending = false
    var draft = ""
    var model: String {
        didSet { defaults.set(model, forKey: "ai.model") }
    }
    /// Let the model call the app's read-only tools (agenda search, picks, team status).
    var useTools: Bool {
        didSet { defaults.set(useTools, forKey: "ai.tools") }
    }
    var contextKinds: Set<AIContextKind> {
        didSet { defaults.set(contextKinds.map(\.rawValue), forKey: Self.contextKey) }
    }
    /// v2: the default became the agenda only, when consent was added. Earlier choices are not carried over.
    static let contextKey = "ai.context.v2"

    // MARK: Consent (App Review 5.1.2(i))

    enum Consent: String, Sendable { case unknown, granted, declined }
    static let consentKey = "ai.consent.v1"
    /// Nothing is sent to OpenRouter unless this is `.granted`. Asked once, before the first question; changeable in settings.
    private(set) var consent: Consent {
        didSet { defaults.set(consent.rawValue, forKey: Self.consentKey) }
    }
    /// True while the consent sheet should show.
    var consentRequested = false
    /// The question waiting for the user's answer on the consent sheet.
    @ObservationIgnored private var pending: (() -> Void)?

    func grantConsent() {
        consent = .granted
        consentRequested = false
        let next = pending
        pending = nil
        next?()
    }

    func declineConsent() {
        consent = .declined
        consentRequested = false
        pending = nil
    }

    /// Settings: withdraw consent. The next question asks again.
    func revokeConsent() {
        stop()
        consent = .unknown
    }

    /// The most turns kept in the conversation, and the most sent back with a question.
    static let turnCap = 200
    static let historyCap = 30
    /// Keep the conversation on this device between launches (off by default). Only the words of each turn are
    /// kept, in a file protected while the device is locked; never the key, the context or the system prompt.
    var keepConversation: Bool {
        didSet {
            defaults.set(keepConversation, forKey: "ai.keepConversation")
            if keepConversation { saveConversation() } else { try? FileManager.default.removeItem(at: conversationFile) }
        }
    }
    /// The parts as last gathered, for the toggles' summaries.
    private(set) var preview: [AIContextPart] = []

    @ObservationIgnored let keys: AIKeyStore
    @ObservationIgnored private let client: OpenRouterClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let gather: @MainActor (Set<AIContextKind>) async -> [AIContextPart]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored let conversationFile: URL

    init(keys: AIKeyStore = .shared, client: OpenRouterClient = OpenRouterClient(), defaults: UserDefaults = .standard,
         gather: @escaping @MainActor (Set<AIContextKind>) async -> [AIContextPart] = { await AIContextGatherer.gather($0) },
         conversationFile: URL = ChatStore.defaultConversationFile) {
        self.keys = keys
        self.conversationFile = conversationFile
        self.client = client
        self.defaults = defaults
        self.gather = gather
        model = defaults.string(forKey: "ai.model") ?? OpenRouter.defaultModel
        useTools = defaults.object(forKey: "ai.tools") as? Bool ?? true
        let saved = (defaults.array(forKey: Self.contextKey) as? [String])?.compactMap(AIContextKind.init(rawValue:))
        contextKinds = Set(saved ?? Array(AIContextKind.defaults))
        consent = Consent(rawValue: defaults.string(forKey: Self.consentKey) ?? "") ?? .unknown
        keepConversation = defaults.bool(forKey: "ai.keepConversation")
        if keepConversation, let data = try? Data(contentsOf: conversationFile) {
            turns = Self.restore(data)
        }
    }

    // MARK: Keeping the conversation

    nonisolated static var defaultConversationFile: URL {
        URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
            .appendingPathComponent("ask-conversation.json")
    }

    private struct SavedTurn: Codable {
        let role: String
        let text: String
        let model: String?
    }

    /// The words of each finished user, assistant and tool turn (errors and debug details are left out).
    static func snapshot(_ turns: [Turn]) throws -> Data {
        let saved = turns.filter { !$0.streaming && $0.role != .error }.suffix(200).map { turn in
            SavedTurn(role: turn.role.name, text: turn.text, model: turn.model)
        }
        return try JSONEncoder().encode(Array(saved))
    }

    static func restore(_ data: Data) -> [Turn] {
        guard let saved = try? JSONDecoder().decode([SavedTurn].self, from: data) else { return [] }
        return saved.compactMap { item in
            let role: Turn.Role? = switch item.role {
            case "user": .user
            case "assistant": .assistant
            case "tool": .tool
            default: nil
            }
            return role.map { Turn(role: $0, text: item.text, model: item.model) }
        }
    }

    private func saveConversation() {
        guard keepConversation, let data = try? Self.snapshot(turns) else { return }
        try? FileManager.default.createDirectory(at: conversationFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: conversationFile, options: [.atomic, .completeFileProtection])
    }

    func isOn(_ kind: AIContextKind) -> Bool { contextKinds.contains(kind) }

    func toggle(_ kind: AIContextKind) {
        if contextKinds.contains(kind) { contextKinds.remove(kind) } else { contextKinds.insert(kind) }
    }

    func refreshPreview() async {
        preview = await gather(Set(AIContextKind.toggleable))
    }

    /// The messages for the next request: the system message, then the conversation (errors left out).
    static func messages(system: String, turns: [Turn], question: String) -> [OpenRouter.Message] {
        var out = [OpenRouter.Message(role: .system, content: system)]
        for turn in turns.suffix(historyCap) where !turn.streaming {
            switch turn.role {
            case .user: out.append(.init(role: .user, content: turn.text))
            case .assistant where !turn.text.isEmpty: out.append(.init(role: .assistant, content: turn.text))
            default: break
            }
        }
        out.append(.init(role: .user, content: question))
        return out
    }

    func send(_ text: String? = nil) {
        let question = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSending else { return }
        guard consent == .granted else {
            if consent == .unknown {
                pending = { [weak self] in self?.send(question) }
                consentRequested = true
            }
            return
        }
        if text == nil { draft = "" }
        isSending = true                       // before the Task, so a second tap cannot send twice
        task = Task { await run(question) }
    }

    /// Ask with a prepared prompt (brief me, plan my day): the prompt shows as the user's turn.
    /// `include` adds context kinds for this question only (the toggles stay as they are).
    func ask(_ prompt: String, showing label: String? = nil, include: Set<AIContextKind> = [],
             extra: @escaping @MainActor () async -> [AIContextPart] = { [] }) {
        guard !isSending else { return }
        guard consent == .granted else {
            if consent == .unknown {
                pending = { [weak self] in self?.ask(prompt, showing: label, include: include, extra: extra) }
                consentRequested = true
            }
            return
        }
        isSending = true
        task = Task { await run(prompt, label: label, include: include, extra: extra) }
    }

    func stop() {
        task?.cancel()
    }

    func clear() {
        stop()
        turns.removeAll()
        saveConversation()
    }

    private func run(_ question: String, label: String? = nil, include: Set<AIContextKind> = [],
                     extra: @MainActor () async -> [AIContextPart] = { [] }) async {
        isSending = true
        defer { isSending = false; task = nil; capTurns(); saveConversation() }
        guard consent == .granted else { return }    // never send without consent, whoever calls
        let history = turns
        turns.append(Turn(role: .user, text: label ?? question))

        let key: String
        do {
            key = try keys.key()
        } catch {
            turns.append(Turn(role: .error, text: error.localizedDescription))
            return
        }
        let kinds = AIContextKind.allowed(include, toggles: contextKinds)
        let parts = await gather(kinds) + extra().filter { kinds.contains($0.kind) }
        let toolSet = useTools ? AITools.definitions(for: kinds) : []
        let system = AIContextAssembler.systemPrompt(parts: parts, now: .now, person: CollabHooks.me()?.name,
                                                     tools: !toolSet.isEmpty)
        var messages = Self.messages(system: system, turns: history, question: question)

        for hop in 0...AITools.maxHops {
            let tools = hop < AITools.maxHops ? toolSet : []
            let bytes = (try? OpenRouter.request(key: key, model: model, messages: messages, tools: tools).httpBody?.count) ?? 0
            var debug = RequestDebug(model: model, systemPrompt: system, parts: parts, messageCount: messages.count,
                                     requestBytes: bytes, sentAt: .now)
            turns.append(Turn(role: .assistant, text: "", model: model, debug: debug, streaming: true))
            let index = turns.count - 1
            let started = ContinuousClock.now
            var calls: [OpenRouter.ToolCall] = []
            var failed = false

            do {
                for try await event in client.stream(key: key, model: model, messages: messages, tools: tools) {
                    switch event {
                    case .text(let text):
                        if debug.firstTokenMs == nil { debug.firstTokenMs = Self.ms(since: started) }
                        turns[index].text += text
                    case .finished(let served, let reason, let usage, let toolCalls):
                        turns[index].model = served ?? model
                        turns[index].usage = usage
                        debug.finishReason = reason
                        calls = toolCalls
                    }
                }
            } catch {
                failed = true
                if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                    turns.append(Turn(role: .error, text: error.localizedDescription))
                } else {
                    turns[index].text += turns[index].text.isEmpty ? "(stopped)" : " (stopped)"
                }
            }
            debug.totalMs = Self.ms(since: started)
            debug.toolCalls = calls.map(\.function.name)
            turns[index].debug = debug
            turns[index].streaming = false
            if !failed, calls.isEmpty, !turns[index].text.isEmpty {
                turns[index].mentions = AITools.mentioned(in: turns[index].text, events: await CollabHooks.agenda())
            }
            guard !failed, !calls.isEmpty, !Task.isCancelled else { return }

            // The model asked for data: run each tool, show it, send the results back.
            messages.append(.init(role: .assistant, content: turns[index].text, toolCalls: calls))
            if turns[index].text.isEmpty { turns.remove(at: index) }
            for call in calls {
                let (result, summary) = await AITools.run(call, allowed: kinds)
                let args = call.function.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                turns.append(Turn(role: .tool, text: "\(call.function.name)(\(args == "{}" ? "" : args)) → \(summary)"))
                messages.append(.init(role: .tool, content: result, toolCallId: call.id))
            }
        }
    }

    private func capTurns() {
        if turns.count > Self.turnCap { turns.removeFirst(turns.count - Self.turnCap) }
    }

    private static func ms(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }
}
