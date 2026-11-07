import Foundation

/// OpenRouter's chat completions API, as promptugal.news `/ask/` uses it (assets/chat/chat-core.js):
/// one POST to `/api/v1/chat/completions`, streamed as server-sent events, `usage: { include: true }`.
///
/// Everything here is pure (no network, no state), so request building and stream parsing are tested
/// without a key. The key goes in one header and nowhere else: not in the URL, the log or the debug panel.
enum OpenRouter {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let host = "openrouter.ai"
    /// The website's default (chat-core.js `DEFAULT_MODEL`).
    static let defaultModel = "anthropic/claude-sonnet-5"
    /// Sent as `HTTP-Referer` and `X-Title`, so OpenRouter's activity page names the app.
    static let referer = "https://promptugal.news/"
    static let title = "PrompTugal iOS"

    struct Model: Identifiable, Hashable, Sendable {
        let id: String
        let label: String
    }

    /// The website's list, in its order, plus the team site's Fable entry (people/<id>/app/data.json `llm.models`).
    static let models: [Model] = [
        Model(id: "anthropic/claude-sonnet-5", label: "Claude Sonnet 5 (default)"),
        Model(id: "anthropic/claude-sonnet-5.5", label: "Claude Sonnet 5.5"),
        Model(id: "anthropic/claude-haiku-5.5", label: "Claude Haiku 5.5 (faster, cheaper)"),
        Model(id: "anthropic/claude-opus-5.5", label: "Claude Opus 5.5 (slower, dearer)"),
        Model(id: "anthropic/claude-fable-5.1", label: "Claude Fable 5.1"),
    ]

    static func label(for model: String) -> String {
        models.first { $0.id == model }?.label ?? model
    }

    // MARK: Messages

    struct Message: Codable, Hashable, Sendable {
        enum Role: String, Codable, Sendable { case system, user, assistant }
        var role: Role
        var content: String
    }

    // MARK: Request

    struct Body: Encodable, Sendable {
        struct Usage: Encodable, Sendable { let include: Bool }
        let model: String
        let messages: [Message]
        let stream: Bool
        let usage: Usage
    }

    enum RequestError: Error, Equatable, LocalizedError {
        case noKey
        case keyHasWhitespace
        var errorDescription: String? {
            switch self {
            case .noKey: "No OpenRouter key. Add yours in Ask → Settings."
            case .keyHasWhitespace: "The key has spaces or line breaks inside it. Paste it again."
            }
        }
    }

    /// The trimmed key, or an error. Keys from openrouter.ai start `sk-or-`; others are allowed (a proxy may issue
    /// its own), so the prefix is only a hint in the UI.
    static func validated(key raw: String) throws -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw RequestError.noKey }
        guard !key.contains(where: { $0.isWhitespace }) else { throw RequestError.keyHasWhitespace }
        return key
    }

    static func looksLikeOpenRouterKey(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sk-or-")
    }

    /// The POST. Streamed unless `stream` is false.
    static func request(key: String, model: String, messages: [Message], stream: Bool = true) throws -> URLRequest {
        let key = try validated(key: key)
        var request = URLRequest(url: endpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(title, forHTTPHeaderField: "X-Title")
        let body = Body(model: model.isEmpty ? defaultModel : model, messages: messages, stream: stream,
                        usage: .init(include: true))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        request.httpBody = try encoder.encode(body)
        return request
    }

    // MARK: Errors from the server

    struct ServerError: Error, Equatable, LocalizedError {
        let status: Int
        let detail: String
        var errorDescription: String? {
            let why = switch status {
            case 401: "the key was refused (401). Check it in Ask → Settings"
            case 402: "the account has no credit (402)"
            case 429: "too many requests (429). Wait a moment"
            case 0: "the stream reported an error"
            default: "HTTP \(status)"
            }
            return "OpenRouter: \(why)\(detail.isEmpty ? "" : " (\(detail))")"
        }
    }

    /// `{"error":{"message":…}}`, or an empty string.
    static func errorMessage(in data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else { return "" }
        return String((error["message"] as? String ?? "").prefix(300))
    }
}

// MARK: - Server-sent events

/// Splits an SSE byte stream into `data:` payloads. Feed it lines (URLSession's `AsyncBytes.lines` drops the
/// line breaks) or raw text chunks; comments (`: OPENROUTER PROCESSING`), blank lines, other fields and
/// `[DONE]` are skipped. Mirrors chat-core.js `sseParser`.
struct SSEParser: Sendable {
    private var buffer = ""

    /// One complete line (no line break). Returns the data payload, if the line carries one.
    static func payload(ofLine raw: String) -> String? {
        let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
        guard line.hasPrefix("data:") else { return nil }
        let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !data.isEmpty, data != "[DONE]" else { return nil }
        return data
    }

    /// A chunk of text that may end mid-line. Returns the payloads of the lines it completes.
    mutating func feed(_ chunk: String) -> [String] {
        buffer += chunk
        var out: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newline])
            buffer = String(buffer[buffer.index(after: newline)...])
            if let data = Self.payload(ofLine: line) { out.append(data) }
        }
        return out
    }
}

/// One parsed stream event's effect.
struct StreamDelta: Equatable, Sendable {
    var text: String = ""
    var model: String?
    var finishReason: String?
    var usage: StreamUsage?
}

struct StreamUsage: Codable, Equatable, Sendable {
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
    var cost: Double?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens", completionTokens = "completion_tokens", totalTokens = "total_tokens", cost
    }
}

/// Folds stream events into one answer (chat-core.js `accumulator`, without tool calls).
struct StreamAccumulator: Sendable {
    private(set) var content = ""
    private(set) var model: String?
    private(set) var finishReason: String?
    private(set) var usage: StreamUsage?
    private(set) var events = 0

    private struct Event: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
            let message: Delta?
            let finishReason: String?
            enum CodingKeys: String, CodingKey { case delta, message, finishReason = "finish_reason" }
        }
        struct Failure: Decodable { let message: String?; let code: Int? }
        let model: String?
        let choices: [Choice]?
        let usage: StreamUsage?
        let error: Failure?
    }

    /// One `data:` payload (or a whole non-streamed JSON body). Returns the new text. Malformed payloads are
    /// ignored, as the website does; an `error` object throws.
    @discardableResult
    mutating func add(_ payload: String) throws -> StreamDelta {
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(Event.self, from: data) else { return StreamDelta() }
        events += 1
        if let error = event.error {
            throw OpenRouter.ServerError(status: error.code ?? 0, detail: error.message ?? "")
        }
        var delta = StreamDelta()
        if let model = event.model { self.model = model; delta.model = model }
        if let usage = event.usage { self.usage = usage; delta.usage = usage }
        if let choice = event.choices?.first {
            if let reason = choice.finishReason { finishReason = reason; delta.finishReason = reason }
            if let text = (choice.delta ?? choice.message)?.content, !text.isEmpty {
                content += text
                delta.text = text
            }
        }
        return delta
    }
}
