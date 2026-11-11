import Foundation
import Testing
@testable import PTNews

// Native articles and transcripts (news app redesign): the twin's address, its parsing, and the speaker turns.

@Suite("Articles and transcripts")
struct ArticleTests {
    @Test("a page on promptugal.news maps to its markdown twin; anything else does not")
    func twinURL() throws {
        let page = try #require(URL(string: "https://promptugal.news/articles/red-wind-warning-lisbon-wednesday.html#top"))
        #expect(ArticleTwin.twinURL(for: page)?.absoluteString == "https://promptugal.news/articles/red-wind-warning-lisbon-wednesday.md")
        let folder = try #require(URL(string: "https://promptugal.news/interviews/buzz-messaging-ai/guy-ben-zvi/"))
        #expect(ArticleTwin.twinURL(for: folder)?.absoluteString == "https://promptugal.news/interviews/buzz-messaging-ai/guy-ben-zvi/index.md")
        #expect(ArticleTwin.twinURL(for: try #require(URL(string: "https://example.com/a.html"))) == nil)
        #expect(ArticleTwin.twinURL(for: try #require(URL(string: "http://promptugal.news/a.html"))) == nil)
        #expect(ArticleTwin.twinURL(for: try #require(URL(string: "https://promptugal.news/a.pdf"))) == nil)
    }

    @Test("the twin's header becomes the title and summary; the body becomes blocks")
    func parse() {
        let text = """
        # Red wind warning

        > Web Summit calls off Wednesday.

        *Source: <https://promptugal.news/a.html> · site v1*

        ---

        ## In short {#short}

        - One [link](../b.html).
        - Two.

        A paragraph
        on two lines.

        1. First.
        2. Second.

        > A quote.

        ![A chart](https://promptugal.news/c.png)

        ::: band
        """
        let article = ArticleTwin.parse(text)
        #expect(article.title == "Red wind warning")
        #expect(article.summary == "Web Summit calls off Wednesday.")
        #expect(article.blocks == [
            .heading(level: 2, text: "In short"),
            .bullets(["One [link](../b.html).", "Two."]),
            .paragraph("A paragraph on two lines."),
            .numbered(["First.", "Second."]),
            .quote("A quote."),
            .image(alt: "A chart", url: "https://promptugal.news/c.png"),
        ])
    }

    @Test("a machine transcript splits into speaker turns")
    func transcript() {
        let text = "Speaker 1: Hello there.\nMore words.\n\nSpeaker 2\nAn answer.\nSpeaker 1: Thanks."
        let turns = TranscriptTurn.parse(text)
        #expect(turns.map(\.speaker) == ["Speaker 1", "Speaker 2", "Speaker 1"])
        #expect(turns.map(\.text) == ["Hello there. More words.", "An answer.", "Thanks."])
    }
}
