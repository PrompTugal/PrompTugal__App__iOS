import Foundation

/// The languages the decks are published in.
public enum DeckLanguage: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case en, pt, fr, es

    public var id: String { rawValue }

    /// The language's own name, for the picker.
    public var displayName: String {
        switch self {
        case .en: "English"
        case .pt: "Português"
        case .fr: "Français"
        case .es: "Español"
        }
    }

    /// The best language to show: the preferred one if the deck has it, else English, else the first
    /// language it has (in the order en, pt, fr, es). Nil only when `available` is empty.
    public static func resolve(_ preferred: DeckLanguage, available: [DeckLanguage]) -> DeckLanguage? {
        chain(preferred, available: available).first
    }

    /// Every language to try, best first: preferred, then English, then the rest in a fixed order.
    public static func chain(_ preferred: DeckLanguage, available: [DeckLanguage]) -> [DeckLanguage] {
        var order: [DeckLanguage] = [preferred, .en]
        order.append(contentsOf: DeckLanguage.allCases)
        var seen = Set<DeckLanguage>()
        return order.filter { available.contains($0) && seen.insert($0).inserted }
    }

    /// The first of the device's preferred languages that the decks support, else English.
    public static func deviceDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> DeckLanguage {
        for tag in preferredLanguages {
            let code = String(tag.prefix(2)).lowercased()
            if let language = DeckLanguage(rawValue: code) { return language }
        }
        return .en
    }
}

/// A text that exists in several languages, with the same fallback as the decks themselves.
public struct LocalizedText: Codable, Sendable, Hashable {
    public var values: [String: String]

    public init(_ values: [String: String]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            values = ["en": text]
        } else {
            values = try container.decode([String: String].self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public func text(in language: DeckLanguage) -> String {
        let available = DeckLanguage.allCases.filter { values[$0.rawValue] != nil }
        guard let best = DeckLanguage.resolve(language, available: available) else { return "" }
        return values[best.rawValue] ?? ""
    }
}

/// One slide. `body` is plain text; lines wrapped in `**` are bold. `notes` are the speaker notes and may
/// be absent. `image` is an absolute URL.
public struct DeckSlide: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var body: String
    public var image: URL?
    public var notes: String?
    /// 0-based position in the deck. Set by `Deck`, not read from the data.
    public private(set) var index: Int = 0

    public var id: Int { index }

    public init(title: String, body: String = "", image: URL? = nil, notes: String? = nil, index: Int = 0) {
        self.title = title
        self.body = body
        self.image = image
        self.notes = notes
        self.index = index
    }

    private enum CodingKeys: String, CodingKey { case title, body, image, notes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        image = (try? c.decodeIfPresent(String.self, forKey: .image)).flatMap { $0 }.flatMap { URL(string: $0) }
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encodeIfPresent(image?.absoluteString, forKey: .image)
        try c.encodeIfPresent(notes, forKey: .notes)
    }

    func numbered(_ index: Int) -> DeckSlide {
        var copy = self
        copy.index = index
        return copy
    }
}

/// One deck in one language: ordered slides.
public struct Deck: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var language: DeckLanguage
    public var title: String
    public var summary: String
    public var slides: [DeckSlide]
    /// The site version the deck was read from, when the source knows it.
    public var version: String?

    public init(id: String, language: DeckLanguage, title: String, summary: String = "",
                slides: [DeckSlide], version: String? = nil) {
        self.id = id
        self.language = language
        self.title = title
        self.summary = summary
        self.slides = slides.enumerated().map { $1.numbered($0) }
        self.version = version
    }

    private enum CodingKeys: String, CodingKey { case id, lang, language, title, summary, slides, version }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let code = try c.decodeIfPresent(String.self, forKey: .lang) ?? c.decodeIfPresent(String.self, forKey: .language) ?? "en"
        self.init(id: id,
                  language: DeckLanguage(rawValue: code) ?? .en,
                  title: try c.decodeIfPresent(String.self, forKey: .title) ?? id,
                  summary: try c.decodeIfPresent(String.self, forKey: .summary) ?? "",
                  slides: try c.decodeIfPresent([DeckSlide].self, forKey: .slides) ?? [],
                  version: try c.decodeIfPresent(String.self, forKey: .version))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(language.rawValue, forKey: .lang)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encode(slides, forKey: .slides)
        try c.encodeIfPresent(version, forKey: .version)
    }
}

/// One line of the deck list: the titles in every language and the languages the deck exists in.
public struct DeckSummary: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// "0" to "9" for the investor decks; nil when the deck has no number.
    public var number: String?
    public var title: LocalizedText
    public var summary: LocalizedText
    public var cover: URL?
    public var languages: [DeckLanguage]

    public init(id: String, number: String? = nil, title: LocalizedText, summary: LocalizedText = LocalizedText([:]),
                cover: URL? = nil, languages: [DeckLanguage] = DeckLanguage.allCases) {
        self.id = id
        self.number = number
        self.title = title
        self.summary = summary
        self.cover = cover
        self.languages = languages
    }

    private enum CodingKeys: String, CodingKey { case id, number, title, summary, cover, languages }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = try c.decodeIfPresent(String.self, forKey: .number)
        title = try c.decode(LocalizedText.self, forKey: .title)
        summary = try c.decodeIfPresent(LocalizedText.self, forKey: .summary) ?? LocalizedText([:])
        cover = (try? c.decodeIfPresent(String.self, forKey: .cover)).flatMap { $0 }.flatMap { URL(string: $0) }
        let codes = try c.decodeIfPresent([String].self, forKey: .languages) ?? DeckLanguage.allCases.map(\.rawValue)
        languages = codes.compactMap { DeckLanguage(rawValue: $0) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(number, forKey: .number)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encodeIfPresent(cover?.absoluteString, forKey: .cover)
        try c.encode(languages.map(\.rawValue), forKey: .languages)
    }
}

/// The list of decks a source offers.
public struct DeckCatalog: Codable, Sendable, Hashable {
    public var version: String?
    public var decks: [DeckSummary]

    public init(version: String? = nil, decks: [DeckSummary]) {
        self.version = version
        self.decks = decks
    }
}
