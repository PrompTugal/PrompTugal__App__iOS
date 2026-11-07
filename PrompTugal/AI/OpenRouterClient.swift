import Foundation

/// Sends a chat to OpenRouter and streams the answer back.
///
/// Uses the shared `HTTPClient`'s session and writes one record per request to `HTTPLog` (Debug → Network):
/// method, the endpoint URL, status, bytes, time. `HTTPClient` keeps no headers or bodies, so the key never
/// reaches the log. (`HTTPClient` has no streaming call yet; this does the same bookkeeping around `bytes(for:)`.)
struct OpenRouterClient: Sendable {
    enum Event: Sendable {
        case text(String)
        case finished(model: String?, reason: String?, usage: StreamUsage?, toolCalls: [OpenRouter.ToolCall])
    }

    let http: HTTPClient

    init(http: HTTPClient = .shared) {
        self.http = http
    }

    /// Streams the answer. Cancel the consuming task to stop: the request is cancelled and logged as such.
    func stream(key: String, model: String, messages: [OpenRouter.Message], tools: [OpenRouter.Tool] = [],
                label: String = "ai.chat") -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try OpenRouter.request(key: key, model: model, messages: messages, tools: tools)
                    try await run(request, label: label, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One whole answer, for "brief me" style one-shot prompts.
    func complete(key: String, model: String, messages: [OpenRouter.Message], label: String = "ai.oneshot",
                  onText: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        var answer = ""
        for try await event in stream(key: key, model: model, messages: messages, label: label) {
            if case .text(let text) = event {
                answer += text
                onText(text)
            }
        }
        return answer
    }

    private func run(_ request: URLRequest, label: String,
                     continuation: AsyncThrowingStream<Event, Error>.Continuation) async throws {
        let clock = ContinuousClock.now
        var record = HTTPRequestRecord(id: UUID(), startedAt: Date(), method: "POST",
                                       url: HTTPClient.redact(OpenRouter.endpoint), host: OpenRouter.host,
                                       label: label, status: nil, bytes: 0, durationMs: 0, error: nil)
        let log = http.log
        func finish(_ error: Error?) async {
            record.durationMs = Double((ContinuousClock.now - clock).components.attoseconds) / 1e15
                + Double((ContinuousClock.now - clock).components.seconds) * 1_000
            if let error { record.error = Self.describe(error) }
            let done = record
            await log.append(done)
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await http.session.bytes(for: request)
        } catch {
            await finish(error)
            throw error
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            await finish(URLError(.badServerResponse))
            throw URLError(.badServerResponse)
        }
        record.status = httpResponse.statusCode

        do {
            guard (200..<300).contains(httpResponse.statusCode) else {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count > 16_384 { break }
                }
                record.bytes = body.count
                let error = OpenRouter.ServerError(status: httpResponse.statusCode,
                                                   detail: OpenRouter.errorMessage(in: body))
                await finish(error)
                throw error
            }

            var accumulator = StreamAccumulator()
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            if contentType.contains("application/json") {
                // Not streamed (a proxy, or stream refused): one JSON body.
                var body = Data()
                for try await byte in bytes { body.append(byte) }
                record.bytes = body.count
                let delta = try accumulator.add(String(decoding: body, as: UTF8.self))
                if !delta.text.isEmpty { continuation.yield(.text(delta.text)) }
            } else {
                for try await line in bytes.lines {
                    record.bytes += line.utf8.count + 1
                    guard let payload = SSEParser.payload(ofLine: line) else { continue }
                    let delta = try accumulator.add(payload)
                    if !delta.text.isEmpty { continuation.yield(.text(delta.text)) }
                }
            }
            continuation.yield(.finished(model: accumulator.model, reason: accumulator.finishReason,
                                         usage: accumulator.usage, toolCalls: accumulator.toolCalls))
            await finish(nil)
        } catch {
            await finish(error)
            throw error
        }
    }

    static func describe(_ error: Error) -> String {
        if error is CancellationError { return "Cancelled" }
        if let error = error as? URLError { return error.code == .cancelled ? "Cancelled" : "URLError \(error.code.rawValue)" }
        if let error = error as? OpenRouter.ServerError { return "OpenRouter \(error.status)" }
        return String(describing: type(of: error))
    }
}
