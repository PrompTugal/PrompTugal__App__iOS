import Foundation
import Testing
@testable import PTWeb

@Suite("Bundled Websites.json")
struct WebsitesJSONTests {
    private func bundled() throws -> [WebsiteShortcut] {
        let url = try #require(Bundle.module.url(forResource: "Websites", withExtension: "json"),
                               "Websites.json is not in the PTWeb bundle")
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
    @Test("Default shortcuts: promptugal.news first, then the team site, nothing else")
    func onlyPrompTugal() throws {
        let url = try #require(Bundle.module.url(forResource: "Websites", withExtension: "json"))
        let shortcuts = try JSONDecoder().decode([WebsiteShortcut].self, from: Data(contentsOf: url))
        let hosts = shortcuts.compactMap { $0.url.host() }
        #expect(hosts == ["promptugal.news", "web-summit.sgit.ai"])
        for dropped in ["riskmandate.ai", "sgit.ai", "newsroom.sgit.ai"] {
            #expect(!hosts.contains(dropped), "\(dropped) must not be a default shortcut")
        }
    }
}

@Suite("Websites: shortcuts column width (iPad Split View)")
struct WebsiteSidebarWidthTests {
    @Test("Full-screen iPad: at most 250 pt")
    func fullScreen() {
        #expect(WebsiteView.sidebarWidth(for: 1194) == 250)
    }

    @Test("Half of a split screen: about a third of the width")
    func halfSplit() {
        #expect(WebsiteView.sidebarWidth(for: 694) == 222)
    }

    @Test("Narrow Split View or Slide Over: no column, the sheet instead")
    func narrow() {
        #expect(WebsiteView.sidebarWidth(for: 507) == nil)
        #expect(WebsiteView.sidebarWidth(for: 320) == nil)
    }
}
