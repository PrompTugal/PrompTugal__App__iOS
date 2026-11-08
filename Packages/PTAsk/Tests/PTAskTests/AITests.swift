import Foundation
import UIKit
import Testing
import PTCore
@testable import PTAsk

/// A made-up key: the format of a real one, the value of none.
private let fakeKey = ["sk", "or", "v1", String(repeating: "0", count: 64)].joined(separator: "-")

@Suite("Ask: OpenRouter request")
struct OpenRouterRequestTests {
    @Test("POST to the chat completions endpoint, key only in the Authorization header")
    func buildsRequest() throws {
        let messages = [OpenRouter.Message(role: .system, content: "sys"), .init(role: .user, content: "Olá")]
        let request = try OpenRouter.request(key: "  \(fakeKey)\n", model: "anthropic/claude-haiku-5.5", messages: messages)
        #expect(request.url == OpenRouter.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeKey)")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        #expect(request.value(forHTTPHeaderField: "X-Title") == "PrompTugal iOS")
        #expect(!(request.url?.absoluteString.contains("sk-or") ?? true))

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "anthropic/claude-haiku-5.5")
        #expect(json["stream"] as? Bool == true)
        #expect((json["usage"] as? [String: Any])?["include"] as? Bool == true)
        let sent = try #require(json["messages"] as? [[String: String]])
        #expect(sent == [["role": "system", "content": "sys"], ["role": "user", "content": "Olá"]])
        #expect(!String(decoding: body, as: UTF8.self).contains(fakeKey), "the key is never in the body")
    }

    @Test("An empty model falls back to the website's default")
    func defaultModel() throws {
        let request = try OpenRouter.request(key: fakeKey, model: "", messages: [])
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "anthropic/claude-sonnet-5")
        #expect(OpenRouter.defaultModel == OpenRouter.models.first?.id)
    }

    @Test("Negative control: no key, or a key with a space inside, builds no request")
    func rejectsBadKeys() {
        #expect(throws: OpenRouter.RequestError.noKey) { try OpenRouter.request(key: "  \n", model: "m", messages: []) }
        #expect(throws: OpenRouter.RequestError.keyHasWhitespace) {
            try OpenRouter.request(key: "sk-or-abc def", model: "m", messages: [])
        }
    }

    @Test("The logged URL is the bare endpoint")
    func loggedURL() {
        #expect(HTTPClient.redact(OpenRouter.endpoint) == "https://openrouter.ai/api/v1/chat/completions")
    }

    @Test("Server errors read like the website's")
    func serverErrors() {
        let body = Data(#"{"error":{"message":"No auth credentials found","code":401}}"#.utf8)
        #expect(OpenRouter.errorMessage(in: body) == "No auth credentials found")
        #expect(OpenRouter.errorMessage(in: Data("not json".utf8)) == "")
        let text = OpenRouter.ServerError(status: 401, detail: "x").localizedDescription
        #expect(text.contains("refused (401)"))
    }
}

@Suite("Ask: server-sent events")
struct SSETests {
    @Test("Data lines are kept; comments, other fields, blank lines and [DONE] are skipped")
    func lines() {
        #expect(SSEParser.payload(ofLine: "data: {\"a\":1}") == "{\"a\":1}")
        #expect(SSEParser.payload(ofLine: "data:{\"a\":1}\r") == "{\"a\":1}")
        #expect(SSEParser.payload(ofLine: ": OPENROUTER PROCESSING") == nil)
        #expect(SSEParser.payload(ofLine: "event: message") == nil)
        #expect(SSEParser.payload(ofLine: "") == nil)
        #expect(SSEParser.payload(ofLine: "data: [DONE]") == nil)
    }

    @Test("Chunks split mid-line are joined before parsing")
    func chunks() {
        var parser = SSEParser()
        #expect(parser.feed("data: {\"x\":").isEmpty)
        #expect(parser.feed("1}\n\ndata: {\"y\"") == ["{\"x\":1}"])
        #expect(parser.feed(":2}\n: keep-alive\ndata: [DONE]\n") == ["{\"y\":2}"])
    }

    @Test("Deltas fold into one answer, with model, finish reason and usage")
    func accumulates() throws {
        var acc = StreamAccumulator()
        let events = [
            #"{"model":"anthropic/claude-sonnet-5","choices":[{"delta":{"role":"assistant","content":"Bom "}}]}"#,
            #"{"choices":[{"delta":{"content":"dia"}}]}"#,
            #"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#,
            #"{"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12,"cost":0.0003}}"#,
            #"not json, ignored"#,
        ]
        var text = ""
        for event in events { text += try acc.add(event).text }
        #expect(text == "Bom dia")
        #expect(acc.content == "Bom dia")
        #expect(acc.model == "anthropic/claude-sonnet-5")
        #expect(acc.finishReason == "stop")
        #expect(acc.usage?.totalTokens == 12)
        #expect(acc.events == 4, "the malformed line is not counted")
    }

    @Test("A whole non-streamed body works too")
    func wholeBody() throws {
        var acc = StreamAccumulator()
        try acc.add(#"{"model":"m","choices":[{"message":{"content":"Olá"},"finish_reason":"stop"}]}"#)
        #expect(acc.content == "Olá")
    }

    @Test("Negative control: an error event mid-stream throws")
    func errorEvent() {
        var acc = StreamAccumulator()
        #expect(throws: OpenRouter.ServerError.self) {
            try acc.add(#"{"error":{"message":"Rate limited","code":429}}"#)
        }
    }
}

@Suite("Ask: context")
struct AIContextTests {
    private func event(_ date: String, _ time: String, _ title: String, slug: String) -> Event {
        Event(date: date, time: time, title: title, place: "Centre Stage", kind: "talk", official: true,
              page: "events/\(slug)/index.html")
    }

    private var events: [Event] {
        [event("2026-11-10", "11:50-12:10", "The agentic internet", slug: "agentic"),
         event("2026-11-10", "09:00-09:20", "Opening", slug: "opening"),
         event("2026-11-11", "10:00-10:30", "Day two", slug: "two")]
    }

    @Test("Today's agenda lists today's sessions in order and marks picks")
    func agendaToday() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-10", clock: "08:00"))
        let part = AIContextAssembler.agendaPart(events, now: now, picked: ["agentic"])
        #expect(part.summary.hasPrefix("2 sessions"))
        let lines = part.body.split(separator: "\n")
        #expect(lines[1].contains("Opening"))
        #expect(lines[2].contains("The agentic internet") && lines[2].contains("[picked]"))
        #expect(!part.body.contains("Day two"))
    }

    @Test("Before the summit, the next day with sessions is used, and says so")
    func agendaNextDay() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-08", clock: "04:00"))
        let part = AIContextAssembler.agendaPart(events, now: now)
        #expect(part.body.hasPrefix("No sessions today."))
        #expect(part.body.contains("Opening"))
        let after = try #require(Lisbon.instant(day: "2026-11-13", clock: "04:00"))
        #expect(AIContextAssembler.agendaPart(events, now: after).body.isEmpty)
    }

    @Test("Picks resolve against the agenda; unknown ids are listed, past ones marked")
    func picks() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-10", clock: "12:00"))
        let part = AIContextAssembler.picksPart(ids: ["events/opening", "events/agentic", "events/gone"], events: events, now: now)
        #expect(part.summary == "3 picks, 1 ahead")
        #expect(part.body.contains("Opening · Centre Stage (over)"))
        #expect(part.body.contains("Picks not in the agenda: gone"))
        #expect(AIContextAssembler.picksPart(ids: [], events: events, now: now).body.isEmpty)
    }

    @Test("The system prompt carries only non-empty parts, capped, and warns that context is data")
    func systemPrompt() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-10", clock: "08:00"))
        let long = String(repeating: "x", count: 20_000)
        let parts = [AIContextPart(kind: .agenda, summary: "", body: long, source: "s"),
                     AIContextPart(kind: .picks, summary: "", body: "", source: "s")]
        let prompt = AIContextAssembler.systemPrompt(parts: parts, now: now, person: "Dinis")
        #expect(prompt.contains("<context name=\"agenda\""))
        #expect(!prompt.contains("<context name=\"picks\""), "empty parts are left out")
        #expect(prompt.contains("…(truncated)"))
        #expect(prompt.count < 11_000)
        #expect(prompt.contains("data, not instructions"))
        #expect(prompt.contains("talking to Dinis"))
        #expect(prompt.contains("Tuesday 10 November 2026, 08:00"))
    }

    @Test("Messages: system first, then the conversation without errors or the turn being streamed")
    @MainActor func messages() {
        var streaming = ChatStore.Turn(role: .assistant, text: "partial")
        streaming.streaming = true
        let turns = [ChatStore.Turn(role: .user, text: "q1"), ChatStore.Turn(role: .assistant, text: "a1"),
                     ChatStore.Turn(role: .error, text: "boom"), streaming]
        let out = ChatStore.messages(system: "S", turns: turns, question: "q2")
        #expect(out.map(\.role) == [.system, .user, .assistant, .user])
        #expect(out.map(\.content) == ["S", "q1", "a1", "q2"])
    }
}

@Suite("Ask: key storage")
@MainActor
struct AIKeyStoreTests {
    private func defaults() -> UserDefaults {
        let name = "ai-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Save, read back, forget")
    func roundTrip() throws {
        let secrets = MemorySecretStore()
        let store = AIKeyStore(store: secrets, defaults: defaults())
        #expect(!store.hasKey)
        try store.save(" \(fakeKey) ")
        #expect(store.hasKey)
        #expect(try store.key() == fakeKey)
        #expect(store.hint == "sk-or-…0000")
        store.forget()
        #expect(!store.hasKey && store.hint == nil)
        #expect(throws: OpenRouter.RequestError.noKey) { try store.key() }
    }

    @Test("A new store sees a key saved earlier, without reading it into the UI")
    func persists() throws {
        let secrets = MemorySecretStore()
        let defaults = defaults()
        try AIKeyStore(store: secrets, defaults: defaults).save(fakeKey)
        let again = AIKeyStore(store: secrets, defaults: defaults)
        #expect(again.hasKey)
        #expect(again.hint != fakeKey && !(again.hint ?? "").contains("0000000000"))
    }

    @Test("Negative control: an invalid key is not stored")
    func rejects() {
        let secrets = MemorySecretStore()
        let store = AIKeyStore(store: secrets, defaults: defaults())
        #expect(throws: OpenRouter.RequestError.keyHasWhitespace) { try store.save("sk-or abc") }
        #expect(!store.hasKey)
        #expect((try? secrets.read(AIKeyStore.account)) == nil)
    }

    @Test("Mask shows six and four characters, and nothing for short input")
    func mask() {
        #expect(AIKeyStore.mask("sk-or-v1-abcdefghijkl") == "sk-or-…ijkl")
        #expect(AIKeyStore.mask("short") == "…")
    }

    @Test("Vault document round trip, and negative control for a bad document")
    func vaultDocument() throws {
        let data = try AIKeyStore.vaultDocument(key: fakeKey, model: "anthropic/claude-sonnet-5", device: "device-1234")
        let (key, model) = try AIKeyStore.key(fromVaultDocument: data)
        #expect(key == fakeKey && model == "anthropic/claude-sonnet-5")
        #expect(throws: (any Error).self) { try AIKeyStore.key(fromVaultDocument: Data(#"{"v":1}"#.utf8)) }
        #expect(throws: (any Error).self) { try AIKeyStore.key(fromVaultDocument: Data(#"{"v":1,"provider":"openrouter","key":" ","savedAt":"x"}"#.utf8)) }
    }

    @Test("Asking without a key gives an error turn and sends nothing")
    func noKeyNoRequest() async {
        let store = ChatStore(keys: AIKeyStore(store: MemorySecretStore(), defaults: defaults()),
                              defaults: defaults(), gather: { _ in [] })
        store.grantConsent()
        store.send("Hello")
        for _ in 0..<200 where store.turns.count < 2 { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.turns.map(\.role) == [.user, .error])
        #expect(store.turns.last?.text.contains("No OpenRouter key") == true)
    }
}

@Suite("Ask: tools")
struct AIToolTests {
    private var events: [Event] {
        [Event(date: "2026-11-10", time: "11:50-12:10", title: "The agentic internet", place: "Centre Stage", kind: "talk", official: true, page: "events/agentic/index.html"),
         Event(date: "2026-11-10", time: "12:00-12:30", title: "Segurança e IA", place: "Stage 2", kind: "talk", official: true, page: "events/seg/index.html"),
         Event(date: "2026-11-11", time: "10:00-10:30", title: "Agentic payments", place: "FinTech Stage", kind: "talk", official: true, page: "events/pay/index.html")]
    }

    @Test("Tool call deltas fold into whole calls, by index")
    func accumulatesCalls() throws {
        var acc = StreamAccumulator()
        try acc.add(#"{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_a","function":{"name":"search_","arguments":"{\"que"}}]}}]}"#)
        try acc.add(#"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"agenda","arguments":"ry\":\"agentic\"}"}}]}}]}"#)
        try acc.add(#"{"choices":[{"delta":{"tool_calls":[{"index":1,"function":{"name":"now","arguments":"{}"}}]},"finish_reason":"tool_calls"}]}"#)
        let calls = acc.toolCalls
        #expect(calls.count == 2)
        #expect(calls[0].id == "call_a" && calls[0].function.name == "search_agenda")
        #expect(AITools.arguments(calls[0].function.arguments) == ["query": "agentic"])
        #expect(calls[1].id == "call_1" && calls[1].function.name == "now")
        #expect(acc.finishReason == "tool_calls")
        var plain = StreamAccumulator()
        try plain.add(#"{"choices":[{"delta":{"content":"hi"}}]}"#)
        #expect(plain.toolCalls.isEmpty, "negative control: no calls without tool deltas")
    }

    @Test("Requests carry tools only when given, and tool messages encode their ids")
    func requestWithTools() throws {
        let call = OpenRouter.ToolCall(id: "c1", function: .init(name: "now", arguments: "{}"))
        let messages: [OpenRouter.Message] = [.init(role: .user, content: "q"),
                                              .init(role: .assistant, content: "", toolCalls: [call]),
                                              .init(role: .tool, content: "12:00", toolCallId: "c1")]
        let with = try OpenRouter.request(key: fakeKey, model: "m", messages: messages, tools: AITools.definitions)
        let body = try #require(with.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect((json["tools"] as? [Any])?.count == AITools.definitions.count)
        #expect(json["tool_choice"] as? String == "auto")
        let sent = try #require(json["messages"] as? [[String: Any]])
        #expect(sent[2]["tool_call_id"] as? String == "c1")
        #expect(((sent[1]["tool_calls"] as? [[String: Any]])?.first?["function"] as? [String: Any])?["name"] as? String == "now")
        let without = try OpenRouter.request(key: fakeKey, model: "m", messages: messages)
        let plainBody = try #require(without.httpBody)
        let plain = try #require(try JSONSerialization.jsonObject(with: plainBody) as? [String: Any])
        #expect(plain["tools"] == nil && plain["tool_choice"] == nil)
    }

    @Test("Agenda search: every word, any case or accent, one day if asked")
    func search() {
        #expect(AITools.search(events, query: "agentic", day: nil).map(\.title) == ["The agentic internet", "Agentic payments"])
        #expect(AITools.search(events, query: "AGENTIC", day: "2026-11-11").map(\.title) == ["Agentic payments"])
        #expect(AITools.search(events, query: "seguranca stage", day: nil).map(\.title) == ["Segurança e IA"])
        #expect(AITools.search(events, query: "agentic nothing", day: nil).isEmpty)
    }

    @Test("On now and next hour")
    func onNow() throws {
        let at = try #require(Lisbon.instant(day: "2026-11-10", clock: "11:55"))
        let (current, next) = AITools.onNow(events, at: at)
        #expect(current.map(\.title) == ["The agentic internet"])
        #expect(next.map(\.title) == ["Segurança e IA"])
    }

    @Test("Tool definitions have unique names and object schemas")
    func definitions() throws {
        let names = AITools.definitions.map(\.function.name)
        #expect(Set(names).count == names.count)
        let data = try JSONEncoder().encode(AITools.definitions)
        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        for tool in decoded {
            let parameters = (tool["function"] as? [String: Any])?["parameters"] as? [String: Any]
            #expect(parameters?["type"] as? String == "object")
        }
    }
}

@Suite("Ask: key check")
struct AIKeyCheckTests {
    @Test("OpenRouter's key info reads into a summary; other shapes are nil")
    @MainActor func parse() throws {
        let info = try #require(AIKeyStore.KeyInfo.parse(Data(#"{"data":{"label":"Summit key","usage":1.25,"limit":null,"is_free_tier":false}}"#.utf8)))
        #expect(info.usage == 1.25 && info.limit == nil)
        #expect(info.summary == "The key works, used $1.25, no limit set.")
        #expect(AIKeyStore.KeyInfo.parse(Data(#"{"error":{"message":"No auth"}}"#.utf8)) == nil)
        #expect(AIKeyStore.KeyInfo.parse(Data("x".utf8)) == nil)
    }
}

@Suite("Ask: sessions named in answers")
struct AIMentionTests {
    private func event(_ title: String, _ slug: String) -> Event {
        Event(date: "2026-11-10", time: "11:00-11:30", title: title, place: "Stage 1", kind: "talk", official: true,
              page: "events/\(slug)/index.html")
    }

    @Test("Full titles found in order, ignoring case and accents; short titles skipped")
    func mentions() {
        let events = [event("The agentic internet: Who controls the web?", "a"), event("Segurança na era da IA", "b"),
                      event("AI", "c")]
        let answer = "Go to SEGURANCA NA ERA DA IA at 11:00, then the agentic internet: who controls the web? AI is everywhere."
        #expect(AITools.mentioned(in: answer, events: events).map(\.page) == ["events/b/index.html", "events/a/index.html"])
        #expect(AITools.mentioned(in: "Nothing relevant here.", events: events).isEmpty, "negative control")
    }
}

@Suite("Ask: keeping the conversation")
@MainActor
struct AIConversationTests {
    @Test("Snapshot keeps words only: no errors, no debug, no streaming turn")
    func snapshot() throws {
        var answer = ChatStore.Turn(role: .assistant, text: "Centre Stage at 11:50.", model: "anthropic/claude-sonnet-5")
        answer.debug = ChatStore.RequestDebug(model: "m", systemPrompt: "SECRET-CONTEXT", parts: [], messageCount: 2,
                                              requestBytes: 10, sentAt: .now)
        var partial = ChatStore.Turn(role: .assistant, text: "half")
        partial.streaming = true
        let turns = [ChatStore.Turn(role: .user, text: "Where is the keynote?"), ChatStore.Turn(role: .tool, text: "now() → 3 on now"),
                     answer, ChatStore.Turn(role: .error, text: "boom"), partial]
        let data = try ChatStore.snapshot(turns)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("SECRET-CONTEXT") && !text.contains("boom") && !text.contains("half"))
        let back = ChatStore.restore(data)
        #expect(back.map(\.text) == ["Where is the keynote?", "now() → 3 on now", "Centre Stage at 11:50."])
        #expect(back.map(\.role) == [.user, .tool, .assistant])
        #expect(back.last?.model == "anthropic/claude-sonnet-5")
        #expect(ChatStore.restore(Data("not json".utf8)).isEmpty, "negative control")
    }

    @Test("Off by default; turning it on writes the file, off deletes it")
    func toggle() throws {
        let name = "ask-keep-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).json")
        let store = ChatStore(keys: AIKeyStore(store: MemorySecretStore(), defaults: defaults), defaults: defaults,
                              gather: { _ in [] }, conversationFile: file)
        #expect(!store.keepConversation)
        store.keepConversation = true
        #expect(FileManager.default.fileExists(atPath: file.path))
        store.keepConversation = false
        #expect(!FileManager.default.fileExists(atPath: file.path))
        defaults.removePersistentDomain(forName: name)
    }
}


@Suite("Ask: consent before anything is sent (App Review 5.1.2(i))")
@MainActor
struct AIConsentTests {
    private func fresh() -> (ChatStore, HTTPLog, UserDefaults, String) {
        let name = "ask-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let secrets = MemorySecretStore()
        let keys = AIKeyStore(store: secrets, defaults: defaults)
        try? keys.save(["sk", "or", "v1", String(repeating: "1", count: 64)].joined(separator: "-"))
        let log = HTTPLog()
        let client = OpenRouterClient(http: HTTPClient(session: HTTPClient.makeSession(), log: log))
        let store = ChatStore(keys: keys, client: client, defaults: defaults, gather: { _ in [] },
                              conversationFile: FileManager.default.temporaryDirectory.appendingPathComponent("\(name).json"))
        return (store, log, defaults, name)
    }

    @Test("Without consent, a question sends nothing and asks for consent")
    func noConsentNoRequest() async throws {
        let (store, log, defaults, name) = fresh()
        #expect(store.consent == .unknown)
        store.send("Where is the keynote?")
        store.ask("Brief me", include: [.team])
        try await Task.sleep(for: .milliseconds(100))
        #expect(store.consentRequested)
        #expect(store.turns.isEmpty)
        #expect(log.records.isEmpty && log.totalRequests == 0)
        #expect(!store.isSending)
        defaults.removePersistentDomain(forName: name)
    }

    @Test("Don't allow: nothing sent, not asked again; withdraw goes back to asking")
    func declined() async throws {
        let (store, log, defaults, name) = fresh()
        store.send("Hi")
        store.declineConsent()
        #expect(store.consent == .declined && !store.consentRequested)
        store.send("Hi again")
        try await Task.sleep(for: .milliseconds(100))
        #expect(!store.consentRequested, "a declined choice is not asked again on every question")
        #expect(store.turns.isEmpty && log.records.isEmpty)
        store.revokeConsent()
        #expect(store.consent == .unknown)
        // The choice is stored.
        store.grantConsent()
        #expect(defaults.string(forKey: ChatStore.consentKey) == "granted")
        defaults.removePersistentDomain(forName: name)
    }

    @Test("Default context is the agenda only; teammates and page are separate switches")
    func minimalDefault() {
        let (store, _, defaults, name) = fresh()
        #expect(store.contextKinds == [.agenda])
        #expect(AIContextKind.toggleable.contains(.teammates) && AIContextKind.toggleable.contains(.page))
        defaults.removePersistentDomain(forName: name)
    }

    @Test("Prepared prompts cannot widen what is shared")
    func allowedKinds() {
        #expect(AIContextKind.allowed([.team, .agents, .plan], toggles: [.agenda]) == [.agenda])
        #expect(AIContextKind.allowed([.agents], toggles: [.agenda, .team]) == [.agenda, .team, .agents])
        #expect(AIContextKind.allowed([.plan], toggles: [.picks]) == [.picks, .plan])
    }

    @Test("Tools are offered only for switched-on data, and refuse otherwise")
    func toolsGated() async {
        #expect(AITools.definitions(for: [.agenda]).map(\.function.name).sorted() == ["now", "search_agenda"])
        #expect(!AITools.definitions(for: [.agenda, .team]).map(\.function.name).contains("where_is_everyone"))
        #expect(AITools.definitions(for: [.teammates]).map(\.function.name) == ["where_is_everyone"])
        let call = OpenRouter.ToolCall(id: "c", function: .init(name: "where_is_everyone", arguments: "{}"))
        let (result, _) = await AITools.run(call, allowed: [.agenda])
        #expect(result.contains("not shared"))
    }

    @Test("The consent text names the provider behind OpenRouter")
    func provider() {
        #expect(OpenRouter.provider(of: "anthropic/claude-sonnet-5") == "Anthropic")
        #expect(OpenRouter.provider(of: "openai/gpt-x") == "OpenAI")
        #expect(OpenRouter.provider(of: "acme/model") == "acme")
    }
}

/// A vault seam for tests: files by vault id, and which one is "mine".
@MainActor
final class FakeCollabVault: CollabVaultAccess {
    var contents: [String: [String: Data]] = [:]       // vault id → path → data
    var ownVaultId: String?
    var reads: [(String, String)] = []
    var isOpen: Bool { !contents.isEmpty }
    var canWrite: Bool { ownVaultId != nil }

    init(own: String?, files: [String: [String: Data]]) {
        ownVaultId = own
        self.contents = files
    }

    func read(_ path: String) async throws -> Data? {
        guard let own = ownVaultId else { throw CollabHooks.HookError.noOwnVault }
        return try await read(path, vaultId: own)
    }
    func read(_ path: String, vaultId: String) async throws -> Data? {
        reads.append((vaultId, path))
        return contents[vaultId]?[path]
    }
    func write(_ path: String, _ data: Data, _ message: String) async throws {
        guard let own = ownVaultId else { throw CollabHooks.HookError.noOwnVault }
        contents[own, default: [:]][path] = data
    }
    func openShared(readKey: String, label: String) async throws -> String { "teammate1" }
    func savePicks(_ document: Data) async throws -> Data { document }
    func writeNewsroomNote(_ path: String, _ data: Data) async throws {}
    func readMaster(_ path: String) async throws -> Data? { nil }
    func files(in folder: String, vaultId: String?) async throws -> [String] { [] }
    func append(_ data: Data, to folder: String, message: String) async throws -> String { folder + "/x.json" }
}

@Suite("Ask key: only from my own vault (S5)")
@MainActor
struct AIKeyVaultOwnershipTests {
    private let teammateKey = ["sk", "or", "v1", String(repeating: "7", count: 64)].joined(separator: "-")

    @Test("A teammate's imported vault is never read for my key")
    func neverFromTeammate() async throws {
        let saved = CollabHooks.vault
        defer { CollabHooks.vault = saved }
        let doc = try AIKeyStore.vaultDocument(key: teammateKey, model: nil)
        let fake = FakeCollabVault(own: nil, files: ["teammate1": [AIKeyStore.vaultPath: doc]])
        CollabHooks.vault = fake
        let name = "ask-own-\(UUID().uuidString)"
        let store = AIKeyStore(store: MemorySecretStore(), defaults: UserDefaults(suiteName: name)!)
        await #expect(throws: CollabHooks.HookError.self) { try await store.loadFromVault() }
        #expect(fake.reads.isEmpty, "nothing read from any vault")
        #expect(!store.hasKey)
        UserDefaults().removePersistentDomain(forName: name)
    }

    @Test("My own vault is read, and only it")
    func fromMine() async throws {
        let saved = CollabHooks.vault
        defer { CollabHooks.vault = saved }
        let doc = try AIKeyStore.vaultDocument(key: teammateKey, model: "anthropic/claude-sonnet-5")
        let fake = FakeCollabVault(own: "mine1", files: ["mine1": [AIKeyStore.vaultPath: doc], "teammate1": [:]])
        CollabHooks.vault = fake
        let name = "ask-own-\(UUID().uuidString)"
        let store = AIKeyStore(store: MemorySecretStore(), defaults: UserDefaults(suiteName: name)!)
        let model = try await store.loadFromVault()
        #expect(model == "anthropic/claude-sonnet-5" && store.hasKey)
        #expect(fake.reads.map(\.0) == ["mine1"])
        UserDefaults().removePersistentDomain(forName: name)
    }
}

@Suite("Ask: links and copy (S7)")
struct AILinkTests {
    @Test("Only https and mailto links can be opened, after confirmation")
    func links() throws {
        #expect(AskLinks.canOpen(try #require(URL(string: "https://promptugal.news/events/x/"))))
        #expect(AskLinks.canOpen(try #require(URL(string: "mailto:someone@example.com"))))
        #expect(!AskLinks.canOpen(try #require(URL(string: "http://example.com"))))
        #expect(!AskLinks.canOpen(try #require(URL(string: "promptugal://open/debug"))))
        #expect(!AskLinks.canOpen(try #require(URL(string: "tel:+351000000"))))
        #expect(!AskLinks.canOpen(try #require(URL(string: "https://user:pw@example.com"))))
    }

    @Test("Copy is local only and expires")
    @MainActor func copy() throws {
        let board = UIPasteboard.withUniqueName()
        AskClipboard.copy("hello", pasteboard: board)
        #expect(board.string == "hello")
        #expect(AskClipboard.lifetime <= 300)
        UIPasteboard.remove(withName: board.name)
    }
}

@Suite("Collab: error text")
struct CollabErrorTextTests {
    @Test("Error text is short and readable")
    func errorText() {
        #expect(CollabErrorText.short(URLError(.notConnectedToInternet)).hasPrefix("No internet"))
        #expect(CollabErrorText.short(URLError(.timedOut)).contains("too long"))
        #expect(CollabErrorText.short(OpenRouter.RequestError.noKey).contains("OpenRouter key"))
        let raw = NSError(domain: "NSOSStatusErrorDomain", code: -25300,
                          userInfo: [NSLocalizedDescriptionKey: "Error Domain=NSOSStatusErrorDomain Code=-25300 \"(null)\""])
        #expect(CollabErrorText.short(raw) == "Something went wrong. Try again.")
    }
}
