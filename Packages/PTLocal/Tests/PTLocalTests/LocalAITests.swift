import Foundation
import Testing
@testable import PTLocal

private func news(_ title: String, summary: String? = nil, path: String? = nil, url: String) -> PlaceSite.News {
    let json: [String: Any?] = ["title": title, "summary": summary, "ai_path": path, "url": url, "steps": 1]
    let data = try! JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
    return try! JSONDecoder().decode(PlaceSite.News.self, from: data)
}

private func entry(_ name: String, what: String?, type: String? = nil) -> PlaceSite.MapEntry {
    let json: [String: Any?] = ["name": name, "what": what, "type": type, "source_url": "https://example.org/\(name.count)"]
    let data = try! JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
    return try! JSONDecoder().decode(PlaceSite.MapEntry.self, from: data)
}

@Suite("Persona ranking")
struct PersonaRankingTests {
    @Test("A named organisation becomes a heavy term; place names and filler words count for nothing")
    func termsFromName() {
        let terms = PersonaRanker.terms(for: "I am from Algarve Evolution")
        #expect(terms.count == 1)
        #expect(terms.first?.label == "Algarve Evolution")
        #expect(terms.first?.needles == ["algarve evolution"])
        #expect(terms.first?.weight == 5)
    }

    @Test("Topics map to their concepts: invest → investment, health → health; the rest stay as words")
    func termsFromTopics() {
        let labels = PersonaRanker.terms(for: "I invest in health tech").map(\.label)
        #expect(labels == ["investment", "health"])
        let other = PersonaRanker.terms(for: "I care about wine and cork").map(\.label)
        #expect(other == ["wine", "cork"])
        #expect(PersonaRanker.terms(for: "I am in Faro, the Algarve").isEmpty)
    }

    @Test("Names keep connecting words and drop the leading I")
    func names() {
        #expect(PersonaRanker.names(in: "I work for Câmara Municipal de Faro") == ["Câmara Municipal de Faro"])
        #expect(PersonaRanker.names(in: "I invest in health tech").isEmpty)
        #expect(PersonaRanker.names(in: "I live in Vila Real de Santo António").isEmpty)
        #expect(PersonaRanker.names(in: "Faro, the Algarve").isEmpty)
    }

    @Test("Matching is accent and case blind, prefix only where asked, and whole words")
    func matching() {
        let terms = PersonaRanker.terms(for: "I invest in health tech")
        let hit = PersonaRanker.match(news("Saúde digital: new fund for clinics", url: "https://a"), terms: terms)
        #expect(hit.matched == ["investment", "health"])
        #expect(hit.score == 2 * 3 + 2 * 3)
        // "sea" must not match "search" or "season".
        let sea = PersonaRanker.terms(for: "the sea")
        #expect(!PersonaRanker.match(news("Search season opens", url: "https://b"), terms: sea).isMatch)
        #expect(PersonaRanker.match(news("A boat on the sea", url: "https://c"), terms: sea).isMatch)
    }

    @Test("Title counts more than summary, summary more than the AI path")
    func fieldWeights() {
        let terms = PersonaRanker.terms(for: "I am from Algarve Evolution")
        let inTitle = PersonaRanker.match(news("Algarve Evolution opens a survey", url: "https://a"), terms: terms)
        let inSummary = PersonaRanker.match(news("A survey", summary: "Run by Algarve Evolution.", url: "https://b"), terms: terms)
        let inPath = PersonaRanker.match(news("A survey", path: "Algarve Evolution is a partner.", url: "https://c"), terms: terms)
        #expect(inTitle.score == 15)
        #expect(inSummary.score == 10)
        #expect(inPath.score == 5)
        #expect(!PersonaRanker.match(news("Unrelated", url: "https://d"), terms: terms).isMatch)
    }

    @Test("Ordering puts matches first, best first, and keeps the rest in their order")
    func ordering() {
        let ordered = PersonaRanker.order(["a", "b", "c", "d", "e"]) { ["b": 2, "d": 5, "e": 2][$0] ?? 0 }
        #expect(ordered == ["d", "b", "e", "a", "c"])
        let none = PersonaRanker.order(["x", "y", "z"]) { _ in 0 }
        #expect(none == ["x", "y", "z"])
    }

    @Test("Map entries rank by name, what and type")
    func entries() {
        let terms = PersonaRanker.terms(for: "I am a startup founder looking for funding")
        let incubator = entry("Algarve STP", what: "A science and technology park with an incubator for startups.")
        let museum = entry("Museu Municipal", what: "The town museum.")
        #expect(PersonaRanker.match(incubator, terms: terms).isMatch)
        #expect(!PersonaRanker.match(museum, terms: terms).isMatch)
    }

    @Test("Across the built-in Algarve, Algarve Evolution finds its own stories first")
    @MainActor func realData() {
        let store = LocalStore(fetch: { _ in throw URLError(.notConnectedToInternet) })
        let sites = ([PlaceDirectory.region] + PlaceDirectory.towns).compactMap { info in store.site(info.id).map { (info: info, site: $0) } }
        #expect(!sites.isEmpty)
        let terms = PersonaRanker.terms(for: "I am from Algarve Evolution")
        let ranked = PersonaRanker.stories(in: sites, terms: terms, limit: 20)
        #expect(!ranked.isEmpty)
        #expect(ranked.first?.match.matched.contains("Algarve Evolution") == true)
        // Best first.
        #expect(zip(ranked, ranked.dropFirst()).allSatisfy { $0.match.score >= $1.match.score })
        // Each story once.
        #expect(Set(ranked.map(\.story.url)).count == ranked.count)
    }

    @Test("A persona survives a restart and its terms come back with it")
    @MainActor func persists() {
        let defaults = UserDefaults(suiteName: "PersonaTests-\(UUID().uuidString)")!
        let store = PersonaStore(defaults: defaults)
        #expect(!store.isOn)
        store.persona = Persona.presets[1]
        #expect(store.terms.map(\.label) == ["investment", "health"])
        let again = PersonaStore(defaults: defaults)
        #expect(again.persona == Persona.presets[1])
        #expect(again.terms.map(\.label) == ["investment", "health"])
        again.persona = nil
        #expect(PersonaStore(defaults: defaults).persona == nil)
    }
}

@Suite("Near me")
struct NearMeTests {
    @Test("Distance: Faro to Lagos is about 67 km")
    func distance() {
        let faro = PlaceDirectory.info("faro")!, lagos = PlaceDirectory.info("lagos")!
        let d = NearMe.distance(lat1: faro.latitude, lon1: faro.longitude, lat2: lagos.latitude, lon2: lagos.longitude)
        #expect(abs(d - 66_000) < 6_000)
        #expect(NearMe.distance(lat1: 37, lon1: -8, lat2: 37, lon2: -8) == 0)
    }

    @Test("Each town's own centre finds that town")
    func ownCentre() {
        for town in PlaceDirectory.towns {
            #expect(NearMe.nearest(latitude: town.latitude, longitude: town.longitude)?.town.id == town.id)
        }
    }

    @Test("Faro airport is nearest Faro and local; Lisbon is far and not local")
    func points() {
        let airport = NearMe.nearest(latitude: 37.0144, longitude: -7.9659)
        #expect(airport?.town.id == "faro")
        #expect(airport?.isLocal == true)
        let sagres = NearMe.nearest(latitude: 37.0086, longitude: -8.9400)
        #expect(sagres?.town.id == "vila-do-bispo")
        let lisbon = NearMe.nearest(latitude: 38.7223, longitude: -9.1393)
        #expect(lisbon != nil)
        #expect(lisbon?.isLocal == false)
        #expect(NearMe.nearest(latitude: 0, longitude: 0, among: []) == nil)
    }

    @Test("Distance text reads well")
    func text() {
        let town = PlaceDirectory.towns[0]
        #expect(NearestTown(town: town, distance: 500).distanceText == "under 1 km")
        #expect(NearestTown(town: town, distance: 4_250).distanceText == "4.2 km" || NearestTown(town: town, distance: 4_250).distanceText == "4.3 km")
        #expect(NearestTown(town: town, distance: 68_400).distanceText == "68 km")
    }
}

@Suite("On-device prompts")
struct LocalPromptTests {
    @Test("The town prompt carries the page's facts, the persona, and stays within the budget")
    @MainActor func townPrompt() throws {
        let store = LocalStore(fetch: { _ in throw URLError(.notConnectedToInternet) })
        let faro = try #require(store.site("faro"))
        let prompt = LocalPrompts.town(faro, persona: Persona.presets[0])
        #expect(prompt.contains("Town: Faro"))
        #expect(prompt.contains("I am from Algarve Evolution"))
        #expect(prompt.count < LocalPrompts.budget + 400)
        if let first = faro.aiNews.first { #expect(prompt.contains(first.title)) }
    }

    @Test("Fit keeps whole lines and says what it left out")
    func fit() {
        let lines = (0..<1000).map { "line \($0) " + String(repeating: "x", count: 40) }
        let text = LocalPrompts.fit(lines)
        #expect(text.count <= LocalPrompts.budget + 80)
        #expect(text.hasSuffix("more lines left out to fit the on-device model.)"))
    }

    @Test("Without a model the status says why, never crashes")
    func status() {
        let status = LocalModel.status
        #expect(!status.text.isEmpty)
    }
}
