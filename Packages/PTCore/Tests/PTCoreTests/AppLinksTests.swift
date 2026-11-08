import Foundation
import Testing
@testable import PTCore

@Suite("App links", .serialized)
struct AppLinksTests {
    @Test("The default scheme is promptugal")
    func defaultScheme() {
        #expect(AppLinks.open("team.schedule")?.absoluteString == "promptugal://open/team.schedule")
    }

    @Test("An app can set its own scheme")
    func customScheme() {
        let saved = AppLinks.scheme
        defer { AppLinks.scheme = saved }
        AppLinks.scheme = "ptteam"
        #expect(AppLinks.open("team.people")?.absoluteString == "ptteam://open/team.people")
    }
}
