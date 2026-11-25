import Foundation
import Testing
@testable import PTLocal

private let heldTown = """
{"id":"faro","name":"Faro","updated":"2026-11-21","ai_news":[
 {"title":"Held story","summary":"Not to be shown","date":"2026-11-16","publisher":"Barlavento",
  "url":"https://www.barlavento.pt/a/","ai_path":"Not to be shown either","steps":1,
  "hold":"held under R12 (ABP v1.18.1): not to be published or shown"},
 {"title":"Cleared story","summary":"Shown","date":"2026-11-15","publisher":"Sul Informação",
  "url":"https://www.sulinformacao.pt/b/","ai_path":"Shown path","steps":0,"hold":"  "},
 {"title":"No outlet","url":"https://example.pt/c/","summary":"x","hold":"held"}
]}
"""

@Suite("Rights hold on by-place stories")
struct RightsHoldTests {
    @Test("A held story keeps only headline, outlet, date and link; a blank hold is no hold")
    func decode() throws {
        let site = try JSONDecoder().decode(PlaceSite.self, from: Data(heldTown.utf8))
        let held = site.aiNews[0]
        #expect(held.isHeld)
        #expect(held.title == "Held story" && held.publisher == "Barlavento" && held.date == "2026-11-16")
        #expect(held.summary == nil && held.aiPath == nil && held.steps == nil && held.stepsLabel == nil)
        #expect(held.sourceURL?.absoluteString == "https://www.barlavento.pt/a/")
        #expect(held.readItAt == "Read it at Barlavento")
        let cleared = site.aiNews[1]
        #expect(!cleared.isHeld)
        #expect(cleared.summary == "Shown" && cleared.aiPath == "Shown path" && cleared.steps == 0)
        #expect(site.aiNews[2].readItAt == "Read it at example.pt")
    }

    @Test("Held stories are never given to the on-device model")
    func prompts() throws {
        let site = try JSONDecoder().decode(PlaceSite.self, from: Data(heldTown.utf8))
        let prompt = LocalPrompts.town(site)
        #expect(!prompt.contains("Held story"))
        #expect(!prompt.contains("Not to be shown"))
        #expect(prompt.contains("Cleared story"))
    }
}
