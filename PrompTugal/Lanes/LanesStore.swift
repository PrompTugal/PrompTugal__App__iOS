import Foundation
import Security
import Observation

/// Lanes I can write to, my own inbox lane, and notes to the newsroom.
@MainActor @Observable
final class LanesStore {
    static let shared = LanesStore()

    struct Sent: Codable, Identifiable, Hashable {
        var id = UUID()
        let at: Date
        let lane: String
        let subject: String
        let bytes: Int
    }

    struct InboxMessage: Identifiable, Hashable {
        let id: String
        let sentAt: Date?
        let text: String
        var subject: String {
            text.components(separatedBy: "\n").first { $0.hasPrefix("Subject:") }
                .map { String($0.dropFirst(8)).trimmingCharacters(in: .whitespaces) } ?? "(no subject)"
        }
        var from: String {
            text.components(separatedBy: "\n").first { $0.hasPrefix("From:") }
                .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        }
        var body: String {
            guard let range = text.range(of: "\r\n\r\n") ?? text.range(of: "\n\n") else { return text }
            return String(text[range.upperBound...])
        }
    }

    private(set) var lanes: [LaneAddress] = [] { didSet { persist() } }
    private(set) var sent: [Sent] = []
    private(set) var inbox: [InboxMessage] = []
    private(set) var inboxError: String?
    private(set) var working = false
    var message: String?

    /// My inbox lane: the descriptor I hand to senders (public), stored as JSON.
    private(set) var myLane: LaneAddress? { didSet { persist() } }

    @ObservationIgnored let log: LanesLog
    @ObservationIgnored private let client: LaneClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: SecretStore
    static let enumKeyAccount = "lanes.enumKey"

    init(log: LanesLog = .shared, client: LaneClient = LaneClient(), defaults: UserDefaults = .standard,
         secrets: SecretStore = KeychainSecretStore(service: "news.promptugal.reader.lanes")) {
        self.log = log
        self.client = client
        self.defaults = defaults
        self.secrets = secrets
        let decoder = JSONDecoder()
        lanes = defaults.data(forKey: "lanes.addresses.v1").flatMap { try? decoder.decode([LaneAddress].self, from: $0) } ?? []
        sent = defaults.data(forKey: "lanes.sent.v1").flatMap { try? decoder.decode([Sent].self, from: $0) } ?? []
        myLane = defaults.data(forKey: "lanes.mine.v1").flatMap { try? decoder.decode(LaneAddress.self, from: $0) }
    }

    private func persist() {
        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(lanes), forKey: "lanes.addresses.v1")
        defaults.set(try? encoder.encode(Array(sent.prefix(100))), forKey: "lanes.sent.v1")
        defaults.set(myLane.flatMap { try? encoder.encode($0) }, forKey: "lanes.mine.v1")
    }

    // MARK: Lanes I write to

    /// A descriptor pasted as JSON, or a link to one (fetched through HTTPClient).
    func addLane(from text: String, name: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var data = Data(trimmed.utf8)
            if let url = URL(string: trimmed), url.scheme == "https" {
                data = try await HTTPClient.shared.get(url, label: "lanes.descriptor")
            }
            var address = try LaneAddress.parse(data)
            if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { address.name = name }
            lanes.removeAll { $0.id == address.id }
            lanes.append(address)
            message = "Added \(address.name). Key \(address.fingerprint) checked against its PEM."
        } catch {
            message = error.localizedDescription
        }
    }

    func remove(_ address: LaneAddress) {
        lanes.removeAll { $0.id == address.id }
    }

    func send(to address: LaneAddress, kind: String, subject: String, body: String) async -> Bool {
        working = true
        defer { working = false }
        let me = CollabHooks.me()
        let mail = LaneMessage(from: "\(me?.name ?? "PrompTugal app") <\(me?.id ?? "app")@promptugal.news>",
                               to: address.name, subject: subject.isEmpty ? "Note from the PrompTugal app" : subject,
                               kind: kind, body: body,
                               extraHeaders: [("X-PrompTugal-Person", me?.id ?? ""), ("X-PrompTugal-Kind", kind)])
        do {
            if address.isNewsroomInbox {
                let note = Self.newsroomNoteObject(kind: kind, text: subject.isEmpty ? body : "\(subject)\n\n\(body)",
                                                       title: nil, path: nil, device: "ios-\(UIDeviceName.short)")
                let data = try LaneAddress.newsroomInboxMessage(note: note, to: address.fingerprint, device: "ios-\(UIDeviceName.short)")
                try await client.send(data, subject: mail.subject, to: address, log: log)
            } else {
                try await client.send(mail, to: address, log: log)
            }
            sent.insert(Sent(at: .now, lane: address.name, subject: mail.subject, bytes: body.utf8.count), at: 0)
            persist()
            message = "Sent to \(address.name). The lane answers only \"ok\": it cannot say who else wrote."
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    // MARK: My inbox

    var hasIdentity: Bool { LaneIdentity.exists }

    var hasEnumKey: Bool { ((try? secrets.read(Self.enumKeyAccount)) ?? nil) != nil }

    func setEnumKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty { try secrets.delete(Self.enumKeyAccount) } else { try secrets.write(trimmed, account: Self.enumKeyAccount) }
            message = trimmed.isEmpty ? "Enumeration key removed." : "Enumeration key saved in the Keychain."
        } catch {
            message = error.localizedDescription
        }
    }

    /// Makes my key pair (once) and a descriptor for my vault's lane, with a fresh append token. The lane still
    /// has to be registered on the vault (`configure`: the vault's write key and an access token), which this
    /// build does not do; the descriptor says what to register.
    func makeMyLane(vaultId: String) {
        do {
            let key = try LaneIdentity.create()
            let (pem, fingerprint) = try LaneIdentity.publicPEM(of: key)
            let name = CollabHooks.me()?.name ?? "PrompTugal app"
            myLane = LaneAddress(name: name, vault: vaultId, endpoint: LaneAddress.defaultEndpoint,
                                 token: myLane?.vault == vaultId ? myLane!.token : LaneIdentity.newToken(),
                                 publicKeyPEM: pem, fingerprint: fingerprint, use: "messages to \(name), from teammates")
            log.add(.encrypt, lane: LanesLog.describe(myLane!), detail: "inbox key pair ready (RSA-4096, Keychain, this device); fingerprint \(fingerprint)")
        } catch {
            message = error.localizedDescription
        }
    }

    func forgetMyLane() {
        LaneIdentity.delete()
        myLane = nil
        inbox = []
        try? secrets.delete(Self.enumKeyAccount)
    }

    /// The inbox the website made for my account (`inbox.json` in my master vault: vault, token, enum key and
    /// the PKCS#8 private key). Held in memory only, dropped when the app quits.
    private(set) var websiteInbox: LaneAddress?
    @ObservationIgnored private var websiteInboxSecrets: (enumKey: String, key: SecKey)?

    func openWebsiteInbox() async {
        guard let vault = CollabHooks.vault, vault.isOpen else { message = CollabHooks.HookError.noVault.localizedDescription; return }
        do {
            guard let data = try await vault.readMaster("inbox.json") else { message = "Your account has no inbox yet (the website makes one)."; return }
            let record = try Self.inboxRecord(data)
            websiteInbox = record.address
            websiteInboxSecrets = (record.enumKey, record.key)
            log.add(.decrypt, lane: LanesLog.describe(record.address), detail: "inbox record read from the master vault; key \(record.address.fingerprint)")
            await refreshInbox()
        } catch {
            message = error.localizedDescription
        }
    }

    /// `{ v, vault, endpoint, token, enum_key, public, private, fingerprint }` (newsroom.sgit.ai inbox.js `create`).
    nonisolated static func inboxRecord(_ data: Data) throws -> (address: LaneAddress, enumKey: String, key: SecKey) {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vault = object["vault"] as? String, let token = object["token"] as? String,
              let enumKey = object["enum_key"] as? String, let publicB64 = object["public"] as? String,
              let privateB64 = object["private"] as? String,
              let spki = Data(base64Encoded: publicB64), let pkcs8 = Data(base64Encoded: privateB64) else {
            throw LaneAddress.Failure.missing("inbox record fields")
        }
        let endpoint = (object["endpoint"] as? String).flatMap(URL.init(string:)) ?? LaneAddress.defaultEndpoint
        let address = LaneAddress(name: "My account inbox", vault: vault, endpoint: endpoint, token: token,
                                  publicKeyPEM: LaneCrypto.pem(spki: spki), fingerprint: LaneCrypto.fingerprint(spki: spki),
                                  use: "my account's inbox", format: LaneAddress.newsroomInboxFormat)
        return (address, enumKey, try LaneCrypto.privateKey(pkcs8: pkcs8))
    }

    func refreshInbox() async {
        let lane: LaneAddress
        let enumKey: String
        let privateKey: SecKey
        if let mine = myLane, let key = (try? secrets.read(Self.enumKeyAccount)) ?? nil, let identity = LaneIdentity.privateKey() {
            lane = mine
            enumKey = key
            privateKey = identity
        } else if let site = websiteInbox, let secrets = websiteInboxSecrets {
            lane = site
            enumKey = secrets.enumKey
            privateKey = secrets.key
        } else {
            inboxError = myLane == nil ? "Set up an inbox, or open your account's inbox from your vault."
                                       : "Add the lane's enumeration key to read it."
            return
        }
        working = true
        defer { working = false }
        let name = LanesLog.describe(lane)
        do {
            let started = ContinuousClock.now
            let entries = try await client.list(lane, enumKey: enumKey)
            log.add(.list, lane: name, ms: LaneClient.ms(since: started), detail: "\(entries.count) waiting")
            let ids = entries.map(\.fileId).filter { id in !inbox.contains { $0.id == id } }
            guard !ids.isEmpty else { inboxError = nil; return }
            var contents: [String: String] = [:]
            for start in stride(from: 0, to: ids.count, by: 100) {
                let batch = Array(ids[start..<min(start + 100, ids.count)])
                contents.merge(try await client.fetch(lane, enumKey: enumKey, fileIds: batch)) { $1 }
            }
            log.add(.fetch, lane: name, bytes: contents.values.reduce(0) { $0 + $1.utf8.count }, detail: "\(contents.count) files")
            for entry in entries where contents[entry.fileId] != nil {
                do {
                    let enc = try LaneCrypto.encText(fromLaneContent: contents[entry.fileId]!)
                    let plain = try LaneCrypto.decrypt(enc, with: privateKey)
                    inbox.append(InboxMessage(id: entry.fileId, sentAt: entry.sentAt, text: Self.readable(plain)))
                    log.add(.decrypt, lane: name, bytes: plain.count, detail: "\(entry.fileId): RSA-OAEP + AES-256-GCM, \(enc.utf8.count) B → \(plain.count) B")
                } catch {
                    log.add(.error, lane: name, detail: "\(entry.fileId): \(error.localizedDescription)")
                }
            }
            inbox.sort { $0.id > $1.id }
            inboxError = nil
        } catch {
            inboxError = error.localizedDescription
            log.add(.error, lane: name, detail: "inbox: \(error.localizedDescription)")
        }
    }

    /// An .eml as is; a newsroom inbox message as headers and its notes, so both read the same in the list.
    nonisolated static func readable(_ plain: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: plain) as? [String: Any],
              object["kind"] as? String == LaneAddress.newsroomInboxFormat,
              let file = object["file"] as? [String: Any] else { return String(decoding: plain, as: UTF8.self) }
        let device = (file["device"] as? [String: Any]).flatMap { ($0["label"] ?? $0["id"]) as? String } ?? "a browser"
        let notes = (file["notes"] as? [[String: Any]]) ?? []
        let reads = (file["reads"] as? [Any])?.count ?? 0
        let lines = notes.map { note in "• \(note["kind"] as? String ?? "note"): \(note["text"] as? String ?? "")" }
        return "From: \(device)\nSubject: \(notes.count) note(s), \(reads) read(s)\n\n" + lines.joined(separator: "\n")
    }

    /// Moves read messages to processed (they can no longer be fetched; they stay on this device until relaunch).
    func markRead(_ ids: [String]) async {
        let pair: (LaneAddress, String)?
        if let mine = myLane, let key = (try? secrets.read(Self.enumKeyAccount)) ?? nil { pair = (mine, key) }
        else if let site = websiteInbox, let secrets = websiteInboxSecrets { pair = (site, secrets.enumKey) }
        else { pair = nil }
        guard let pair, !ids.isEmpty else { return }
        let (lane, enumKey) = pair
        do {
            try await client.markProcessed(lane, enumKey: enumKey, fileIds: ids)
            log.add(.markProcessed, lane: LanesLog.describe(lane), detail: "\(ids.count) files")
        } catch {
            message = error.localizedDescription
        }
    }

    // MARK: Newsroom notes

    /// One note in the newsroom's notes format (`sgit.notes.v1`, newsroom.sgit.ai assets/vault-pane/notes.js):
    /// `{ id, at, kind, path, title, n, story, text, quote, persona, device, sent_at }`.
    nonisolated static func newsroomNote(kind: String, text: String, title: String?, path: String?, device: String,
                             at date: Date = .now, id: String = UUID().uuidString.lowercased()) throws -> (path: String, data: Data) {
        let object = newsroomNoteObject(kind: kind, text: text, title: title, path: path, device: device, at: date, id: id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
        return ("notes/\(id).json", data)
    }

    nonisolated static func newsroomNoteObject(kind: String, text: String, title: String?, path: String?, device: String,
                                   at date: Date = .now, id: String = UUID().uuidString.lowercased()) -> [String: Any] {
        let iso = ISO8601DateFormatter.collabJS.string(from: date)
        let object: [String: Any] = ["id": id, "at": iso, "kind": kind, "path": path.map { $0 as Any } ?? NSNull(), "title": title.map { $0 as Any } ?? NSNull(),
                                     "n": NSNull(), "story": NSNull(), "text": String(text.prefix(2_000)), "quote": NSNull(),
                                     "persona": NSNull(), "device": device, "sent_at": iso, "source": "promptugal-ios"]
        return object
    }

    /// The newsroom's notes lane is a vault of the reader's own that the newsroom reads with its read key.
    func sendToNewsroom(kind: String, text: String) async -> Bool {
        guard let vault = CollabHooks.vault, vault.isOpen else {
            message = CollabHooks.HookError.noVault.localizedDescription
            return false
        }
        working = true
        defer { working = false }
        do {
            let page = CollabHooks.currentPage
            let note = try Self.newsroomNote(kind: kind, text: text, title: page?.title, path: page?.url?.path(),
                                             device: "ios-\(UIDeviceName.short)")
            try await vault.writeNewsroomNote(note.path, note.data)
            log.add(.vaultNote, lane: "Newsroom notes lane", bytes: note.data.count, detail: "\(note.path) committed to the notes lane vault")
            sent.insert(Sent(at: .now, lane: "Newsroom notes", subject: String(text.prefix(60)), bytes: note.data.count), at: 0)
            persist()
            message = "Saved to your newsroom notes lane. The newsroom reads it with the lane's read key."
            return true
        } catch {
            log.add(.error, lane: "Newsroom notes lane", detail: error.localizedDescription)
            message = error.localizedDescription
            return false
        }
    }
}

/// A short, stable, non-identifying device label for note records.
enum UIDeviceName {
    static var short: String {
        let key = "lanes.deviceLabel"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let made = String(UUID().uuidString.lowercased().prefix(8))
        UserDefaults.standard.set(made, forKey: key)
        return made
    }
}
