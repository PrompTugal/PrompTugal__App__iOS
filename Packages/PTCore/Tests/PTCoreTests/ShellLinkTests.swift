import Foundation
import Testing
@testable import PTCore

@Suite("Shell links")
struct ShellLinkTests {
    private func link(_ target: String) -> URL {
        URL(string: "promptugal://open/now?url=" + target.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)!
    }

    @Test("The public app opens PrompTugal.news pages and nothing on the team site")
    func publicHosts() {
        let site = ShellLink.page(in: link("https://promptugal.news/events/a/index.html"), hosts: ShellLink.publicHosts) { _ in false }
        #expect(site?.url.host() == "promptugal.news")
        let team = ShellLink.page(in: link("https://web-summit.sgit.ai/briefing"), hosts: ShellLink.publicHosts) { _ in false }
        #expect(team == nil)
        let other = ShellLink.page(in: link("https://example.com/"), hosts: ShellLink.publicHosts) { _ in false }
        #expect(other == nil)
    }

    @Test("The Team app keeps both of its sites")
    func teamHosts() {
        let team = ShellLink.page(in: link("https://web-summit.sgit.ai/briefing")) { _ in false }
        #expect(team?.url.host() == "web-summit.sgit.ai")
    }

    @Test("A checkout page is blocked on any host, and a session slug opens its page")
    func blockedAndSession() {
        #expect(ShellLink.page(in: link("https://promptugal.news/checkout"), hosts: ShellLink.publicHosts) { _ in true } == nil)
        let session = URL(string: "promptugal://open/now?session=opening-night")!
        #expect(ShellLink.page(in: session, hosts: ShellLink.publicHosts) { _ in false }?.url.path() == "/events/opening-night/index.html")
    }
}
