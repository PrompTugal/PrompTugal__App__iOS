import Foundation
import Testing
@testable import PrompTugal

@Suite("PrompTugal public app")
struct PublicAppTests {
    @Test("the app bundle is the existing PrompTugal record")
    func bundleId() {
        #expect(Bundle.main.bundleIdentifier == "news.promptugal.reader")
    }

    @Test("Info.plist declares the promptugal URL scheme")
    func urlScheme() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains("promptugal"))
    }

    @Test("the agenda seed is bundled and decodes (offline first launch)")
    func agendaSeed() {
        #expect(AgendaSeed.events().count > 150)
    }
}
