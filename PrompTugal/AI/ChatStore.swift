import Foundation
import Observation

/// One conversation with Ask. Lives for the app's run; nothing is saved to disk (as on the website, where the
/// conversation stays in the tab).
@MainActor @Observable
final class ChatStore {
    static let shared = ChatStore()

    struct Turn: Identifiable, Equatable {
        enum Role: Equatable { case user, assistant, error, tool }
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
        didSet { defaults.set(contextKinds.map(\.rawValue), forKey: "ai.context") }
    }
    /// The parts as last gathered, for the toggles' summaries.
    private(set) var preview: [AIContextPart] = []

    @ObservationIgnored let keys: AIKeyStore
    @ObservationIgnored private let client: OpenRouterClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let gather: @MainActor (Set<AIContextKind>) async -> [AIContextPart]
    @ObservationIgnored private var task: Task<Void, Never>?

    init(keys: AIKeyStore = .shared, client: OpenRouterClient = OpenRouterClient(), defaults: UserDefaults = .standard,
         gather: @escaping @MainActor (Set<AIContextKind>) async -> [AIContextPart] = { await AIContextGatherer.gather($0) }) {
        self.keys = keys
        self.client = client
        self.defaults = defaults
        self.gather = gather
        model = defaults.string(forKey: "ai.model") ?? OpenRouter.defaultModel
        useTools = defaults.object(forKey: "ai.tools") as? Bool ?? true
        let saved = (defaults.array(forKey: "ai.context") as? [String])?.compactMap(AIContextKind.init(rawValue:))
        contextKinds = Set(saved ?? [.agenda, .picks, .team])
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
        for turn in turns where !turn.streaming {
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
        if text == nil { draft = "" }
        task = Task { await run(question) }
    }

    /// Ask with a prepared prompt (brief me, plan my day): the prompt shows as the user's turn.
    /// `include` adds context kinds for this question only (the toggles stay as they are).
    func ask(_ prompt: String, showing label: String? = nil, include: Set<AIContextKind> = [],
             extra: @escaping @MainActor () async -> [AIContextPart] = { [] }) {
        guard !isSending else { return }
        task = Task { await run(prompt, label: label, include: include, extra: extra) }
    }

    func stop() {
        task?.cancel()
    }

    func clear() {
        stop()
        turns.removeAll()
    }

    private func run(_ question: String, label: String? = nil, include: Set<AIContextKind> = [],
                     extra: @MainActor () async -> [AIContextPart] = { [] }) async {
        isSending = true
        defer { isSending = false; task = nil }
        let history = turns
        turns.append(Turn(role: .user, text: label ?? question))

        let key: String
        do {
            key = try keys.key()
        } catch {
            turns.append(Turn(role: .error, text: error.localizedDescription))
            return
        }
        let parts = await gather(contextKinds.union(include)) + extra()
        let system = AIContextAssembler.systemPrompt(parts: parts, now: .now, person: CollabHooks.me()?.name,
                                                     tools: useTools)
        var messages = Self.messages(system: system, turns: history, question: question)

        for hop in 0...AITools.maxHops {
            let tools = useTools && hop < AITools.maxHops ? AITools.definitions : []
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
                let (result, summary) = await AITools.run(call)
                let args = call.function.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                turns.append(Turn(role: .tool, text: "\(call.function.name)(\(args == "{}" ? "" : args)) → \(summary)"))
                messages.append(.init(role: .tool, content: result, toolCallId: call.id))
            }
        }
    }

    private static func ms(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }
}
