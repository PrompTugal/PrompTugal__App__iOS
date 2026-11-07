import Foundation
import Testing
@testable import PrompTugal

@Suite("Bundled Websites.json")
struct WebsitesJSONTests {
    private func bundled() throws -> [WebsiteShortcut] {
        let url = try #require(Bundle.main.url(forResource: "Websites", withExtension: "json"),
                               "Websites.json is not in the app bundle")
        return try JSONDecoder().decode([WebsiteShortcut].self, from: Data(contentsOf: url))
    }

    @Test("Decodes, and every shortcut is valid")
    func decodes() throws {
        let shortcuts = try bundled()
        #expect(!shortcuts.isEmpty)
        for shortcut in shortcuts {
            #expect(shortcut.isValid, "\(shortcut.id) is not valid")
        }
    }

    @Test("Ids are unique and PrompTugal comes first")
    func idsAndOrder() throws {
        let shortcuts = try bundled()
        #expect(Set(shortcuts.map(\.id)).count == shortcuts.count)
        #expect(shortcuts.first?.id == "promptugal")
        #expect(shortcuts.first?.url.host == "promptugal.news")
    }

    @Test("Plain http and credentials in URLs are rejected")
    func rejectsUnsafeURLs() throws {
        let json = #"""
        [{"id":"a","name":"A","url":"http://example.com/","icon":"globe","color":"red"},
         {"id":"b","name":"B","url":"https://user:pw@example.com/","icon":"globe","color":"red"}]
        """#
        let shortcuts = try JSONDecoder().decode([WebsiteShortcut].self, from: Data(json.utf8))
        #expect(shortcuts.allSatisfy { !$0.isValid })
    }
}

@Suite("Positioning")
struct PositioningTests {
    @Test("Default shortcuts are PrompTugal's own sites and team data sources only")
    func onlyPrompTugal() throws {
        let url = try #require(Bundle.main.url(forResource: "Websites", withExtension: "json"))
        let shortcuts = try JSONDecoder().decode([WebsiteShortcut].self, from: Data(contentsOf: url))
        let hosts = Set(shortcuts.compactMap { $0.url.host() })
        #expect(hosts == ["promptugal.news", "web-summit.sgit.ai", "newsroom.sgit.ai"])
    }
}
