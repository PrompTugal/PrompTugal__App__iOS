import Foundation
import Observation

// MARK: - Persona

/// Who the reader says they are or what they care about ("I am from Algarve Evolution", "I invest in health tech").
/// Kept on this device only. Turns on persona mode: the Algarve home and the town pages reorder and highlight what
/// matters to it, by a deterministic ranking that works with no model (PersonaRanker), and Apple Intelligence adds a
/// briefing when the device has it.
public struct Persona: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    /// A short label for the header ("Algarve Evolution").
    public let label: String
    /// The reader's own words, as typed or picked.
    public let text: String

    public init(id: String, label: String, text: String) {
        self.id = id
        self.label = label
        self.text = text
    }

    /// A persona from words the reader typed.
    public static func custom(_ text: String) -> Persona {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.count > 40 ? String(trimmed.prefix(38)) + "…" : trimmed
        return Persona(id: "custom", label: label, text: trimmed)
    }

    /// Ready-made personas, each matching things the Algarve sites really cover.
    public static let presets: [Persona] = [
        Persona(id: "algarve-evolution", label: "Algarve Evolution", text: "I am from Algarve Evolution"),
        Persona(id: "health-investor", label: "Health tech investor", text: "I invest in health tech"),
        Persona(id: "startup-founder", label: "Startup founder", text: "I am a startup founder looking for partners and funding"),
        Persona(id: "tourism", label: "Tourism and hotels", text: "I work in tourism and hotels"),
        Persona(id: "university", label: "Student or researcher", text: "I study or do research at the university"),
        Persona(id: "council", label: "Public sector", text: "I work for a council or the public sector"),
        Persona(id: "sea", label: "The sea economy", text: "I care about the ocean, fishing and the sea economy"),
        Persona(id: "developer", label: "Developer", text: "I am a software developer looking for events and meetups"),
    ]
}

/// The persona this device is in, if any. Persisted in UserDefaults; never sent anywhere.
@MainActor @Observable
public final class PersonaStore {
    public static let shared = PersonaStore()
    static let key = "local.persona"

    public var persona: Persona? {
        didSet {
            if let persona, let data = try? JSONEncoder().encode(persona) {
                defaults.set(data, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
            terms = persona.map { PersonaRanker.terms(for: $0.text) } ?? []
        }
    }

    /// The persona's terms, worked out once per change.
    public private(set) var terms: [PersonaTerm] = []

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Persona.self, from: $0) }
        persona = saved
        terms = saved.map { PersonaRanker.terms(for: $0.text) } ?? []
    }

    public var isOn: Bool { persona != nil }

    public func match(_ story: PlaceSite.News) -> PersonaMatch { PersonaRanker.match(story, terms: terms) }
    public func match(_ entry: PlaceSite.MapEntry) -> PersonaMatch { PersonaRanker.match(entry, terms: terms) }
}

// MARK: - Ranking

/// One thing the persona cares about, and the words that show it in a story.
public struct PersonaTerm: Sendable, Hashable {
    /// Shown on a highlighted item ("health", "Algarve Evolution").
    public let label: String
    /// Normalised words or phrases (lowercase, no accents). A trailing `*` matches any word that starts with it.
    public let needles: [String]
    /// How much one match counts: a named organisation counts more than a topic.
    public let weight: Int
}

/// How well one item fits the persona: zero means not at all.
public struct PersonaMatch: Sendable, Hashable {
    public let score: Int
    /// The labels of the terms that matched, in the persona's order.
    public let matched: [String]

    public static let none = PersonaMatch(score: 0, matched: [])
    public var isMatch: Bool { score > 0 }
}

public struct RankedStory: Sendable, Hashable, Identifiable {
    public var id: String { town + "|" + story.id }
    public let town: String
    public let townID: String
    public let story: PlaceSite.News
    public let match: PersonaMatch
}

public struct RankedEntry: Sendable, Hashable, Identifiable {
    public var id: String { town + "|" + entry.id }
    public let town: String
    public let townID: String
    public let entry: PlaceSite.MapEntry
    public let match: PersonaMatch
}

/// A deterministic keyword and entity ranking: no model needed, the same answer every time, and every highlight can
/// say which words matched.
public enum PersonaRanker {
    /// Topics a reader may name, each with the words that show it in the Algarve's stories (English and Portuguese).
    static let concepts: [(label: String, needles: [String])] = [
        ("health", ["health*", "healthcare", "saude", "hospital*", "medic*", "clinic*", "biotech*", "pharma*", "patient*", "wellbeing", "wellness"]),
        ("investment", ["invest*", "funding", "fund", "funds", "venture*", "capital", "financ*", "seed", "grant*", "angel*", "bank*", "prr"]),
        ("startups", ["startup*", "start-up*", "founder*", "incubat*", "accelerat*", "entrepreneur*", "empreendedor*", "spin-off*", "spinoff*"]),
        ("tourism", ["touris*", "turismo", "hotel*", "hospitality", "travel*", "visitor*", "booking*", "golf", "restaurant*"]),
        ("the sea", ["ocean*", "sea", "marine", "maritime", "blue economy", "fish*", "aquacultur*", "port", "ports", "mar"]),
        ("education", ["universit*", "ualg", "school*", "student*", "course*", "training", "educat*", "research*", "academ*", "escola*"]),
        ("public sector", ["council*", "camara", "municipal*", "municipio", "public sector", "government*", "city hall", "mayor", "autarquia*", "ccdr*", "amal"]),
        ("software", ["software", "developer*", "digital*", "data", "cloud", "coding", "programm*", "gdg", "devfest"]),
        ("agriculture", ["agricultur*", "farm*", "water", "drought", "irrigat*", "citrus", "crop*", "agro*"]),
        ("energy", ["energy", "solar", "renewable*", "electric*", "hydrogen"]),
        ("events", ["event*", "conference*", "festival*", "meetup*", "summit*", "workshop*", "hackathon*"]),
        ("security", ["secur*", "cyber*", "privacy"]),
        ("jobs and skills", ["job*", "employ*", "skills", "hiring", "talent*", "workforce", "emprego*"]),
        ("business", ["compan*", "business*", "empresa*", "sme*", "industr*", "adoption"]),
    ]

    static let stopwords: Set<String> = [
        "i", "im", "am", "a", "an", "the", "from", "in", "on", "at", "of", "for", "to", "and", "or", "with", "about",
        "my", "me", "we", "our", "us", "is", "are", "be", "been", "work", "works", "working", "interested", "interest",
        "care", "cares", "into", "who", "what", "like", "love", "looking", "want", "do", "does", "doing", "as",
        "ai", "artificial", "intelligence", "news", "local", "people", "things", "stuff", "tech", "technology",
        "sou", "de", "da", "das", "dos", "em", "e", "o", "os", "na", "no", "um", "uma", "eu", "trabalho",
        "study", "studies", "partners", "new",
    ]

    /// Place names count for nothing: every story in the Algarve says "Algarve".
    static let placeWords: Set<String> = {
        var words: Set<String> = ["algarve", "portugal", "portuguese", "algarvio", "town", "region"]
        for info in PlaceDirectory.all {
            for word in PersonaRanker.tokens(info.name) where word.count > 2 { words.insert(word) }
        }
        return words
    }()

    /// Lowercase, no accents.
    static func normalise(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }

    /// Words of normalised text, split on anything not a letter, digit or hyphen.
    static func tokens(_ text: String) -> [String] {
        normalise(text).split { !($0.isLetter || $0.isNumber || $0 == "-") }.map(String.init)
    }

    /// Runs of two or more capitalised words in the reader's own text, as names ("Algarve Evolution",
    /// "Universidade do Algarve"). Short connecting words may sit inside a run.
    static func names(in text: String) -> [String] {
        // A name never runs across punctuation: "Faro, the Algarve" is two places, not one name.
        text.split { ",.;:!?()\n".contains($0) }.flatMap { names(inClause: String($0)) }
    }

    private static func names(inClause text: String) -> [String] {
        let connectors: Set<String> = ["do", "da", "de", "dos", "das", "of", "the", "and", "e"]
        let words = text.split { !($0.isLetter || $0.isNumber || $0 == "-" || $0 == "&") }.map(String.init)
        var names: [String] = []
        var run: [String] = []
        func close() {
            while let last = run.last, connectors.contains(last.lowercased()) { run.removeLast() }
            while let first = run.first, connectors.contains(first.lowercased()) { run.removeFirst() }
            let capitals = run.filter { $0.first?.isUppercase == true }
            // Only places ("Vila Real de Santo António") is not an organisation: place names count for nothing.
            let onlyPlaces = capitals.allSatisfy { tokens($0).allSatisfy { placeWords.contains($0) } }
            if capitals.count >= 2 && !onlyPlaces { names.append(run.joined(separator: " ")) }
            run = []
        }
        for (index, word) in words.enumerated() {
            let capital = word.first?.isUppercase == true || word.first?.isNumber == true
            if capital && !(index == 0 && word == "I") && word != "I" && !(word.count == 2 && word == "AI") {
                run.append(word)
            } else if !run.isEmpty && connectors.contains(word.lowercased()) {
                run.append(word)
            } else {
                close()
            }
        }
        close()
        return names
    }

    /// The persona's terms: names it gives (weight 5), the topics it names (weight 2) and any other word it uses (2).
    public static func terms(for text: String) -> [PersonaTerm] {
        var out: [PersonaTerm] = []
        var nameWords = Set<String>()
        for name in names(in: text) {
            let needle = tokens(name).joined(separator: " ")
            guard !needle.isEmpty, !out.contains(where: { $0.needles == [needle] }) else { continue }
            out.append(PersonaTerm(label: name, needles: [needle], weight: 5))
            nameWords.formUnion(tokens(name))
        }
        var seenConcepts = Set<String>()
        for word in tokens(text) where word.count >= 3 && !stopwords.contains(word) && !nameWords.contains(word) {
            if let concept = concepts.first(where: { concept in
                concept.label == word || concept.needles.contains { needleMatches(word: word, needle: $0) }
            }) {
                if seenConcepts.insert(concept.label).inserted {
                    out.append(PersonaTerm(label: concept.label, needles: concept.needles, weight: 2))
                }
            } else if !placeWords.contains(word), !out.contains(where: { $0.label == word }) {
                out.append(PersonaTerm(label: word, needles: [word.count >= 4 ? word + "*" : word], weight: 2))
            }
        }
        return out
    }

    /// Whether one word fits one single-word needle.
    static func needleMatches(word: String, needle: String) -> Bool {
        if needle.hasSuffix("*") { return word.hasPrefix(String(needle.dropLast())) }
        return word == needle
    }

    /// Whether a needle (one word or a phrase) is in the words of a text.
    static func contains(_ words: [String], needle: String) -> Bool {
        let parts = needle.split(separator: " ").map(String.init)
        guard let first = parts.first else { return false }
        if parts.count == 1 { return words.contains { needleMatches(word: $0, needle: first) } }
        guard words.count >= parts.count else { return false }
        for start in 0...(words.count - parts.count) {
            var all = true
            for (offset, part) in parts.enumerated() where !needleMatches(word: words[start + offset], needle: part) {
                all = false
                break
            }
            if all { return true }
        }
        return false
    }

    /// Scores weighted fields: each term counts once, at the weight of the best field it is in.
    static func match(fields: [(text: String?, weight: Int)], terms: [PersonaTerm]) -> PersonaMatch {
        guard !terms.isEmpty else { return .none }
        let tokenised = fields.map { (words: tokens($0.text ?? ""), weight: $0.weight) }
        var score = 0
        var matched: [String] = []
        for term in terms {
            let best = tokenised.filter { field in term.needles.contains { contains(field.words, needle: $0) } }.map(\.weight).max()
            if let best {
                score += term.weight * best
                matched.append(term.label)
            }
        }
        return PersonaMatch(score: score, matched: matched)
    }

    public static func match(_ story: PlaceSite.News, terms: [PersonaTerm]) -> PersonaMatch {
        match(fields: [(story.title, 3), (story.summary, 2), (story.aiPath, 1), (story.publisher, 1)], terms: terms)
    }

    public static func match(_ entry: PlaceSite.MapEntry, terms: [PersonaTerm]) -> PersonaMatch {
        match(fields: [(entry.name, 3), (entry.what, 2), (entry.type, 2), (entry.aiPath, 1)], terms: terms)
    }

    /// Items with a match first, best first; ties and the rest keep their order. Stable, so the page does not jump.
    public static func order<T>(_ items: [T], by score: (T) -> Int) -> [T] {
        items.enumerated()
            .map { (index: $0.offset, item: $0.element, score: score($0.element)) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .map(\.item)
    }

    /// Every story in the places given that matches, best first, each story once.
    public static func stories(in sites: [(info: PlaceInfo, site: PlaceSite)], terms: [PersonaTerm], limit: Int = 8) -> [RankedStory] {
        var seen = Set<String>()
        var out: [RankedStory] = []
        for (info, site) in sites {
            for story in site.aiNews where seen.insert(story.url).inserted {
                let found = match(story, terms: terms)
                if found.isMatch { out.append(RankedStory(town: info.name, townID: info.id, story: story, match: found)) }
            }
        }
        return Array(order(out) { $0.match.score }.prefix(limit))
    }

    /// Every organisation on the places' AI maps that matches, best first, each name once.
    public static func entries(in sites: [(info: PlaceInfo, site: PlaceSite)], terms: [PersonaTerm], limit: Int = 8) -> [RankedEntry] {
        var seen = Set<String>()
        var out: [RankedEntry] = []
        for (info, site) in sites {
            for entry in site.aiMap where seen.insert(normalise(entry.name)).inserted {
                let found = match(entry, terms: terms)
                if found.isMatch { out.append(RankedEntry(town: info.name, townID: info.id, entry: entry, match: found)) }
            }
        }
        return Array(order(out) { $0.match.score }.prefix(limit))
    }
}
