import CryptoKit
import Foundation
import Observation
import PTCore
import SwiftUI

// The app is English and Portuguese (Portugal) only (Dinis, 26 Nov). The interface comes from this package's String
// Catalog; a place's own prose (its mandate, centre of gravity, the summaries of its stories) comes from the site's
// translation memory when the app runs in Portuguese, always marked as machine translation with the English one tap
// away. Articles and the headlines of stories stay as published. No translation is made on the device.
//
// The memory (c.ios.explore's spec, s. 1): https://promptugal.news/data/i18n/tm/pt-PT/<2 hex>.json, entries keyed by
// the first 16 hex of SHA-256 over the normalised English (NFC, CR/CRLF to LF, runs of space, tab or NBSP to one
// space, spaces around newlines removed, 3+ newlines to 2, trimmed; the site's board/team/translator/tools/tm.mjs).

enum PlacesLanguage {
    /// True when the app shows its Portuguese (Portugal) localisation.
    static var isPortuguese: Bool {
        (Bundle.module.preferredLocalizations.first ?? "en").lowercased().hasPrefix("pt")
    }

    /// Dates and numbers in the language the app shows.
    static var locale: Locale { Locale(identifier: isPortuguese ? "pt_PT" : "en_GB") }

    static let culture = "pt-PT"
}

struct TMEntry: Decodable, Sendable, Equatable {
    var text: String
    /// True when a second reader checked it.
    var checked: Bool
    var by: String

    init(text: String, checked: Bool = false, by: String = "") { self.text = text; self.checked = checked; self.by = by }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let t = c.string("t"), !t.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: AnyKey("t"), in: c, debugDescription: "no translation")
        }
        text = t
        checked = c.lenient(Bool.self, "ok") ?? false
        by = c.string("by") ?? ""
    }
}

/// One shard of the memory: key to entry. A bad entry is dropped, never the shard.
struct TMShard: Decodable, Sendable, Equatable {
    var entries: [String: TMEntry]

    init(entries: [String: TMEntry]) { self.entries = entries }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var found: [String: TMEntry] = [:]
        for key in c.allKeys {
            if let entry = try? c.decode(TMEntry.self, forKey: key) { found[key.stringValue] = entry }
        }
        entries = found
    }
}

enum TMKey {
    /// The site's normalisation of an English segment.
    static func normalise(_ text: String) -> String {
        var s = text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        s = s.replacingOccurrences(of: "[ \\t\\u00A0]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first 16 hex of SHA-256 over the normalised English.
    static func key(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(normalise(text).utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}

/// The pt-PT memory, fetched one shard at a time as the screens need it and kept on the device.
@MainActor @Observable
final class PlacesTranslation {
    static let shared = PlacesTranslation()

    private(set) var shards: [String: RemoteFeed<TMShard>] = [:]
    /// The reader asked to see the English.
    var showEnglish = false

    static func shardURL(_ shard: String) -> URL {
        URL(string: "https://promptugal.news/data/i18n/tm/\(PlacesLanguage.culture)/\(shard).json")!
    }

    /// The translation of an English segment, if the memory has it and the app runs in Portuguese.
    func entry(_ english: String) -> TMEntry? {
        guard PlacesLanguage.isPortuguese, !english.isEmpty else { return nil }
        let key = TMKey.key(english)
        return shards[String(key.prefix(2))]?.value?.entries[key]
    }

    /// The text to show: the translation unless the reader asked for the English.
    func text(_ english: String) -> String {
        guard !showEnglish, let entry = entry(english) else { return english }
        return entry.text
    }

    /// Fetches the shards these segments need (nothing in English).
    func load(_ segments: [String]) async {
        guard PlacesLanguage.isPortuguese else { return }
        let needed = Set(segments.filter { !$0.isEmpty }.map { String(TMKey.key($0).prefix(2)) })
        await withTaskGroup(of: Void.self) { group in
            for shard in needed {
                let feed = feed(shard)
                group.addTask { await feed.load() }
            }
        }
    }

    private func feed(_ shard: String) -> RemoteFeed<TMShard> {
        if let feed = shards[shard] { return feed }
        let feed = RemoteFeed<TMShard>(name: "tm.\(PlacesLanguage.culture).\(shard)", url: Self.shardURL(shard))
        feed.freshFor = 86_400
        shards[shard] = feed
        return feed
    }
}

extension PlaceFile {
    /// The prose the memory translates: mandate, centre of gravity, story summaries (headlines stay as published).
    var translatableProse: [String] {
        [mandate, gravity?.text ?? ""] + aiNews.map(\.summary)
    }
}

/// The line under translated prose: machine translation, by whom, and a tap to see the English (or back).
struct TranslationNote: View {
    let entry: TMEntry?
    @State private var translation = PlacesTranslation.shared

    var body: some View {
        if let entry {
            Button {
                withAnimation(.snappy) { translation.showEnglish.toggle() }
            } label: {
                Label(label(entry), systemImage: "character.bubble")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("places.translation")
        }
    }

    private func label(_ entry: TMEntry) -> String {
        if translation.showEnglish {
            return String(localized: "In English, as published · see the translation", bundle: .module)
        }
        return entry.checked
            ? String(localized: "Machine translation, checked · see in English", bundle: .module)
            : String(localized: "Machine translation, not reviewed · see in English", bundle: .module)
    }
}
