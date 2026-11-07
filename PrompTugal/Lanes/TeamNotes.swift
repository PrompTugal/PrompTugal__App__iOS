import Foundation
import Observation
import SwiftUI

/// Team notes through vaults: each person appends notes to `lanes/team/` in their own vault (one new file per
/// note, signed by the device that wrote it, so devices never conflict), and reads the same folder in the vaults
/// of teammates whose read keys they hold (linked in "Where is everyone"). No server lane, no shared write key.
struct TeamNote: Codable, Identifiable, Hashable, Sendable {
    static let folder = "lanes/team"
    static let schema = "promptugal-team-note/v1"

    var schema = TeamNote.schema
    let id: String
    let at: String
    let kind: String
    let text: String
    let from: String
    let fromName: String
    /// A session slug or page the note is about, when there is one.
    var about: String?
    /// Where it was read from: "me" or a vault id. Not stored.
    var source: String?

    enum CodingKeys: String, CodingKey { case schema, id, at, kind, text, from, fromName = "from_name", about }

    var date: Date? { ISO8601DateFormatter.collabJS.date(from: at) ?? ISO8601DateFormatter().date(from: at) }

    static func make(kind: String, text: String, from: CollabIdentity?, about: String?, at date: Date = .now) -> TeamNote {
        TeamNote(id: UUID().uuidString.lowercased(), at: ISO8601DateFormatter.collabJS.string(from: date), kind: kind,
                 text: String(text.prefix(4_000)), from: from?.id ?? "unknown", fromName: from?.name ?? "Someone",
                 about: about)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Decodes one note file; anything else (another schema, bad JSON) is nil.
    static func decode(_ data: Data, source: String) -> TeamNote? {
        guard var note = try? JSONDecoder().decode(TeamNote.self, from: data), note.schema == schema,
              !note.text.isEmpty else { return nil }
        note.source = source
        return note
    }

    /// Newest first, at most `limit`, duplicates (same id) once.
    static func merge(_ notes: [TeamNote], limit: Int = 200) -> [TeamNote] {
        var seen = Set<String>()
        return notes.sorted { $0.at > $1.at }.filter { seen.insert($0.id).inserted }.prefix(limit).map { $0 }
    }
}

@MainActor @Observable
final class TeamNotesStore {
    static let shared = TeamNotesStore()

    private(set) var notes: [TeamNote] = []
    private(set) var loading = false
    private(set) var errors: [String: String] = [:]
    var message: String?

    /// Files read per vault, newest names first (names start with the UTC time).
    let perVault = 40

    func load(coordination: CoordinationStore = .shared, log: LanesLog = .shared) async {
        guard let vault = CollabHooks.vault, vault.isOpen else {
            message = CollabHooks.HookError.noVault.localizedDescription
            return
        }
        loading = true
        defer { loading = false }
        var collected: [TeamNote] = []
        var sources: [(label: String, vaultId: String?)] = [("me", nil)]
        sources += coordination.linkedVaults.sorted { $0.key < $1.key }.map { (label: $0.key, vaultId: Optional($0.value)) }
        for source in sources {
            do {
                let paths = try await vault.files(in: TeamNote.folder, vaultId: source.vaultId).sorted(by: >).prefix(perVault)
                var read = 0
                for path in paths {
                    let content: Data?
                    if let id = source.vaultId {
                        content = try await vault.read(path, vaultId: id)
                    } else {
                        content = try await vault.read(path)
                    }
                    if let content, let note = TeamNote.decode(content, source: source.vaultId ?? "me") {
                        collected.append(note)
                        read += 1
                    }
                }
                errors[source.label] = nil
                log.add(.list, lane: "Team notes · \(source.label)", detail: "\(paths.count) files in \(TeamNote.folder), \(read) notes")
            } catch {
                errors[source.label] = error.localizedDescription
                log.add(.error, lane: "Team notes · \(source.label)", detail: error.localizedDescription)
            }
        }
        notes = TeamNote.merge(collected)
        message = nil
    }

    func post(kind: String, text: String, about: String? = nil, log: LanesLog = .shared) async -> Bool {
        guard let vault = CollabHooks.vault, vault.canWrite else {
            message = CollabHooks.HookError.noWritableVault.localizedDescription
            return false
        }
        do {
            let note = TeamNote.make(kind: kind, text: text, from: CollabHooks.me(), about: about)
            let data = try note.encoded()
            let path = try await vault.append(data, to: TeamNote.folder, message: "Team note from the app")
            log.add(.vaultNote, lane: "Team notes · me", bytes: data.count, detail: "\(path) committed, signed by this device")
            var shown = note
            shown.source = "me"
            notes = TeamNote.merge([shown] + notes)
            message = "Posted to your vault. Teammates with your read key see it."
            return true
        } catch {
            message = error.localizedDescription
            log.add(.error, lane: "Team notes · me", detail: error.localizedDescription)
            return false
        }
    }
}

/// The team notes section, for `LanesView`.
struct TeamNotesSection: View {
    var store: TeamNotesStore = .shared
    @State private var draft = ""
    @State private var posting = false

    var body: some View {
        Section {
            HStack(alignment: .bottom) {
                TextField("A note for the team", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                Button(posting ? "Posting…" : "Post") {
                    posting = true
                    Task {
                        if await store.post(kind: "note", text: draft) { draft = "" }
                        posting = false
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posting
                          || !(CollabHooks.vault?.canWrite ?? false))
            }
            if store.notes.isEmpty {
                Text(store.loading ? "Reading vaults…" : "No team notes yet.").foregroundStyle(.secondary)
            }
            ForEach(store.notes.prefix(30)) { note in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(note.fromName).font(.subheadline.bold())
                        Spacer()
                        if let date = note.date {
                            Text(date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(note.text).font(.subheadline).textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(store.errors.sorted { $0.key < $1.key }, id: \.key) { entry in
                Text("\(entry.key): \(entry.value)").font(.caption).foregroundStyle(.orange)
            }
            if let message = store.message { Text(message).font(.footnote) }
        } header: {
            HStack {
                Text("Team notes")
                Spacer()
                Button("Refresh") { Task { await store.load() } }.font(.caption)
            }
        } footer: {
            Text("Each note is a new file in \(TeamNote.folder) of your own vault, signed by this device. You see your notes and those of teammates whose vault you linked in Where is everyone.")
        }
        .task { await store.load() }
    }
}
