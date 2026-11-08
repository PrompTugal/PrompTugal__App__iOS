import Foundation
import Testing
@testable import PTWeb

@Suite("Web page stays on its own site")
@MainActor
struct WebPageHostTests {
    private let home = URL(string: "https://promptugal.news/")!

    private func leaves(_ address: String, from home: URL? = nil) -> Bool {
        WebPageModel.leavesSite(URL(string: address)!, from: home ?? self.home)
    }

    @Test func theOwnSiteAndItsSubdomainsStay() {
        #expect(!leaves("https://promptugal.news/events/a/index.html"))
        #expect(!leaves("https://www.promptugal.news/agenda"))
        #expect(!leaves("https://app.promptugal.news/x"))
        #expect(!leaves("https://PromPtugal.News/x"))
    }

    @Test func otherSitesLeaveEvenWhenTheNameLooksSimilar() {
        #expect(leaves("https://websummit.com/"))
        #expect(leaves("https://portugalstartupnews.com/"))
        #expect(leaves("https://promptugal.news.evil.example/"))
        #expect(leaves("https://notpromptugal.news/"))
        #expect(leaves("http://example.org/"))
    }

    @Test func aWwwHomeStillAcceptsTheBareHost() {
        let www = URL(string: "https://www.promptugal.news/")!
        #expect(!leaves("https://promptugal.news/x", from: www))
        #expect(leaves("https://websummit.com/", from: www))
    }

    @Test func nonWebSchemesAreNotLeaving() {
        #expect(!leaves("about:blank"))
        #expect(!leaves("blob:https://promptugal.news/1234"))
    }
}
