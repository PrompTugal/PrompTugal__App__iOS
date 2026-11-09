import Combine
import Foundation
import Security

// MARK: Transport

/// Moves sealed envelopes between lanes. The envelope is already sealed and signed: a transport never sees content.
public protocol MessageTransport: Sendable {
    /// Why messaging cannot send or receive yet, or nil when it can.
    var notReadyReason: String? { get }
    func append(_ envelope: MessageEnvelope, toLaneOf name: String) async throws
    func inbox() async throws -> [(fileID: String, envelope: MessageEnvelope)]
    func markProcessed(_ fileIDs: [String]) async throws
}

public enum MessageTransportFailure: Error, LocalizedError, Equatable {
    case notSwitchedOn(String)
    case noLane(String)
    public var errorDescription: String? {
        switch self {
        case .notSwitchedOn(let why): why
        case .noLane(let name): "\(name) has no messaging lane yet."
        }
    }
}

/// Until the team's shared messaging vault exists (conductor@web-summit.dinis makes it), messaging says so plainly.
public struct NotSwitchedOnTransport: MessageTransport {
    public init() {}
    public var notReadyReason: String? { "Messaging is not switched on yet: the team's messaging vault is being set up." }
    public func append(_ envelope: MessageEnvelope, toLaneOf name: String) async throws { throw MessageTransportFailure.notSwitchedOn(notReadyReason!) }
    public func inbox() async throws -> [(fileID: String, envelope: MessageEnvelope)] { [] }
    public func markProcessed(_ fileIDs: [String]) async throws {}
}

/// In memory, for tests and previews: one shared post office, each name with its own lane.
public actor MemoryPostOffice {
    var lanes: [String: [(String, MessageEnvelope)]] = [:]
    public init() {}
    func append(_ e: MessageEnvelope, to name: String) { lanes[name, default: []].append((UUID().uuidString, e)) }
    func list(_ name: String) -> [(String, MessageEnvelope)] { lanes[name] ?? [] }
    func remove(_ ids: [String], from name: String) { lanes[name]?.removeAll { ids.contains($0.0) } }
}

public struct MemoryTransport: MessageTransport {
    public let office: MemoryPostOffice
    public let me: String
    public init(office: MemoryPostOffice, me: String) { self.office = office; self.me = me }
    public var notReadyReason: String? { nil }
    public func append(_ envelope: MessageEnvelope, toLaneOf name: String) async throws { await office.append(envelope, to: name) }
    public func inbox() async throws -> [(fileID: String, envelope: MessageEnvelope)] { await office.list(me).map { (fileID: $0.0, envelope: $0.1) } }
    public func markProcessed(_ fileIDs: [String]) async throws { await office.remove(fileIDs, from: me) }
}

/// The shared messaging vault's append lanes (sgit.ai /api/append-lanes, through LaneClient's request builder).
/// Its details come from the team (a JSON the conductor gives each person); the append tokens can only write,
/// and the inbox key reads only this person's lane. Kept in the Keychain, this device only.
public struct MessagingVaultConfig: Codable, Equatable, Sendable {
    public var endpoint: URL
    public var vault: String
    /// name (person id or agent) -> that lane's append token
    public var lanes: [String: String]
    /// The key that lists and reads my own lane.
    public var inboxKey: String
    public var me: String

    static let account = "messaging-vault-v1"
    public static func load() -> MessagingVaultConfig? {
        MessagingDevice.read(account).flatMap { try? JSONDecoder().decode(MessagingVaultConfig.self, from: $0) }
    }
    public func save() throws { try MessagingDevice.write(Self.account, try JSONEncoder().encode(self)) }
    public static func parse(_ text: String) throws -> MessagingVaultConfig { try JSONDecoder().decode(Self.self, from: Data(text.utf8)) }
}

public struct LaneMessageTransport: MessageTransport {
    public let config: MessagingVaultConfig
    public init(config: MessagingVaultConfig) { self.config = config }
    public var notReadyReason: String? { nil }

    func address(_ name: String, token: String) -> LaneAddress {
        LaneAddress(name: name, vault: config.vault, endpoint: config.endpoint, token: token, publicKeyPEM: "", fingerprint: "")
    }

    public func append(_ envelope: MessageEnvelope, toLaneOf name: String) async throws {
        guard let token = config.lanes[name] else { throw MessageTransportFailure.noLane(name) }
        let text = String(decoding: try JSONEncoder().encode(envelope), as: UTF8.self)
        let request = try LaneClient.writeRequest(to: address(name, token: token), payload: LaneCrypto.lanePayload(encText: text))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true else { throw URLError(.badServerResponse) }
    }

    public func inbox() async throws -> [(fileID: String, envelope: MessageEnvelope)] {
        let mine = address(config.me, token: config.lanes[config.me] ?? "")
        let client = LaneClient()
        let entries = try await client.list(mine, enumKey: config.inboxKey)
        guard !entries.isEmpty else { return [] }
        let contents = try await client.fetch(mine, enumKey: config.inboxKey, fileIds: entries.map(\.fileId))
        return contents.compactMap { id, content in
            guard let text = try? LaneCrypto.encText(fromLaneContent: content),
                  let env = try? JSONDecoder().decode(MessageEnvelope.self, from: Data(text.utf8)) else { return nil }
            return (fileID: id, envelope: env)
        }
    }

    public func markProcessed(_ fileIDs: [String]) async throws {
        let mine = address(config.me, token: config.lanes[config.me] ?? "")
        try await LaneClient().markProcessed(mine, enumKey: config.inboxKey, fileIds: fileIDs)
    }
}

// MARK: The store

/// One conversation in the list.
public struct MessageThreadSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var isGroup: Bool
    public var isEmail: Bool
    public var last: TeamMessage
    public var unread: Int
}

/// Every message this device holds, by thread, stored in its own folder (Application Support/Messages), and the
/// polling that fills it. Refused messages are counted, never shown.
@MainActor
public final class MessageStore: ObservableObject {
    public enum Status: Equatable { case notSwitchedOn(String), upToDate(Date), sending, offline(String) }

    @Published public private(set) var byThread: [String: [TeamMessage]] = [:]
    @Published public private(set) var status: Status
    @Published public private(set) var refusedCount = 0
    @Published public private(set) var directory: MessageDirectory?
    /// Messages that arrived on the last poll, for notifications.
    public var onNew: (([TeamMessage]) -> Void)?

    public let me: String
    let identity: () throws -> MessageIdentity
    var transport: MessageTransport
    let folder: URL
    var lastRead: [String: String] = [:]
    var processed: Set<String> = []
    var pollTask: Task<Void, Never>?
    var pace: Pace = .appOpen

    /// 10 seconds on the Messages screen, a minute with the app open, then every 20 minutes (Dinis's plan).
    public enum Pace: Sendable { case screenOpen, appOpen, idle
        var seconds: Double { switch self { case .screenOpen: 10; case .appOpen: 60; case .idle: 1_200 } }
    }

    public init(me: String, transport: MessageTransport, folder: URL? = nil,
                identity: @escaping () throws -> MessageIdentity, directory: MessageDirectory? = nil) {
        self.me = me
        self.transport = transport
        self.identity = identity
        self.directory = directory
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Messages", isDirectory: true)
        status = transport.notReadyReason.map(Status.notSwitchedOn) ?? .offline("Not checked yet")
        load()
    }

    /// The device's store: the vault's lanes once configured, else "not switched on".
    public static func forDevice(person: String) -> MessageStore {
        let transport: MessageTransport = MessagingVaultConfig.load().map { LaneMessageTransport(config: $0) } ?? NotSwitchedOnTransport()
        return MessageStore(me: person, transport: transport, identity: { try MessagingDevice.identity(person: person) })
    }

    public func useVault(_ config: MessagingVaultConfig) throws {
        try config.save()
        transport = LaneMessageTransport(config: config)
        status = .offline("Not checked yet")
    }

    // MARK: Reading

    public var threads: [MessageThreadSummary] {
        byThread.compactMap { id, list in
            guard let last = list.last else { return nil }
            let unread = list.filter { $0.from != me && $0.at > (lastRead[id] ?? "") }.count
            return MessageThreadSummary(id: id, title: title(of: id, last: last), isGroup: id.hasPrefix("group:"),
                                        isEmail: { if case .email = last { return true }; return false }(), last: last, unread: unread)
        }.sorted { $0.last.at > $1.last.at }
    }

    public var unreadTotal: Int { threads.reduce(0) { $0 + $1.unread } }

    public func messages(in thread: String) -> [TeamMessage] { byThread[thread] ?? [] }

    public func markRead(_ thread: String) {
        guard let last = byThread[thread]?.last else { return }
        lastRead[thread] = last.at
        saveState()
    }

    func title(of thread: String, last: TeamMessage) -> String {
        if thread.hasPrefix("group:") { return "The " + thread.dropFirst("group:".count) }
        let others = (last.to + [last.from]).filter { $0 != me }
        return others.first ?? thread
    }

    // MARK: Sending

    /// `kind` is a Messaging-FS kind: "text", or "location" for the Team app's "I'm at" (a place, never GPS).
    public func send(text: String, to names: [String], group: String? = nil, kind: String = "text") async throws {
        let others = names.filter { $0 != me }
        let thread = group.map(MessageThread.group) ?? MessageThread.direct([me] + others)
        try await deliver(.chat(ChatMessage(thread: thread, from: me, to: others, kind: kind, text: text)), to: others)
    }

    /// True when messages can be sent and received (the vault's lanes are configured).
    public var isSwitchedOn: Bool { transport.notReadyReason == nil }

    public func sendEmail(subject: String, text: String, to names: [String], thread: String? = nil, replyTo: String? = nil) async throws {
        let others = names.filter { $0 != me }
        let msg = EmailMessage(thread: thread ?? "mail:" + UUID().uuidString.lowercased(), from: me, to: others,
                               subject: subject, text: text, replyTo: replyTo)
        try await deliver(.email(msg), to: others)
    }

    func deliver(_ message: TeamMessage, to names: [String]) async throws {
        if let why = transport.notReadyReason { throw MessageTransportFailure.notSwitchedOn(why) }
        let dir = try await currentDirectory()
        let readers = (names + [me]).flatMap { dir.readers(of: $0) }
        let env = try MessageCrypto.seal(message, to: readers, as: try identity())
        status = .sending
        for name in Set(names) { try await transport.append(env, toLaneOf: name) }
        keep(message)
        lastRead[message.thread] = message.at
        saveState()
        status = .upToDate(.now)
    }

    // MARK: Receiving

    public func poll() async {
        if let why = transport.notReadyReason { status = .notSwitchedOn(why); return }
        do {
            let dir = try await currentDirectory()
            let me = try identity()
            var fresh: [TeamMessage] = []
            var done: [String] = []
            for (fileID, env) in try await transport.inbox() {
                done.append(fileID)
                guard !processed.contains(env.id) else { continue }
                do {
                    let m = try MessageCrypto.open(env, as: me, signer: dir.signer)
                    keep(m)
                    fresh.append(m)
                } catch {
                    refusedCount += 1     // never shown; counted for "1 message could not be verified"
                }
                processed.insert(env.id)
            }
            if !done.isEmpty { try await transport.markProcessed(done) }
            saveState()
            status = .upToDate(.now)
            if !fresh.isEmpty { onNew?(fresh) }
        } catch {
            status = .offline(error.localizedDescription)
        }
    }

    public func setPace(_ pace: Pace) {
        guard pace != self.pace || pollTask == nil else { return }
        self.pace = pace
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                let seconds = await self?.pace.seconds ?? 60
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    public func stop() { pollTask?.cancel(); pollTask = nil }

    func currentDirectory() async throws -> MessageDirectory {
        if let directory { return directory }
        let d = try await MessageDirectory.fetch()
        directory = d
        return d
    }

    public func refreshDirectory() async { directory = try? await MessageDirectory.fetch() }

    // MARK: Storage (this device's own folder)

    func keep(_ m: TeamMessage) {
        var list = byThread[m.thread] ?? []
        guard !list.contains(where: { $0.id == m.id }) else { return }
        list.append(m)
        list.sort { $0.at < $1.at }
        byThread[m.thread] = list
        let dir = folder.appendingPathComponent("inbox", isDirectory: true).appendingPathComponent(Self.safe(m.thread), isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        try? (try? m.encoded())?.write(to: dir.appendingPathComponent(m.id + ".json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func safe(_ s: String) -> String { String(s.map { $0.isLetter || $0.isNumber || "@.+:-_".contains($0) ? $0 : "_" }) }

    struct State: Codable { var lastRead: [String: String]; var processed: [String] }

    func load() {
        let inbox = folder.appendingPathComponent("inbox", isDirectory: true)
        let fm = FileManager.default
        for dir in (try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? [] {
            for f in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where f.pathExtension == "json" {
                if let data = try? Data(contentsOf: f), let m = try? TeamMessage.decode(data) {
                    byThread[m.thread, default: []].append(m)
                }
            }
        }
        for k in byThread.keys { byThread[k]?.sort { $0.at < $1.at } }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("state.json")),
           let s = try? JSONDecoder().decode(State.self, from: data) {
            lastRead = s.lastRead
            processed = Set(s.processed)
        }
    }

    func saveState() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let s = State(lastRead: lastRead, processed: Array(processed.suffix(5_000)))
        try? (try? JSONEncoder().encode(s))?.write(to: folder.appendingPathComponent("state.json"), options: .atomic)
    }
}
