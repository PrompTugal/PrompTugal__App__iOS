import Foundation
import Testing
@testable import PTNews

// The interview videos (news app redesign): the site's list, the manifest, and the rules that keep a bad entry out.

@Suite("Videos")
struct VideoTests {
    /// The shape promptugal.news serves at api/v1/live/videos.json (10 November 2026).
    static let list = """
    {"version":"v0.1.1022","about":"Interview videos for the apps, newest first.","count":1,"items":[{
      "title":"Guy Ben Zvi, Buzz Messaging AI: interview at Web Summit's opening night","person":"Guy Ben Zvi",
      "company":"Buzz Messaging AI","interviewer":"Dinis Cruz","date":"2026-11-10","recorded":"2026-11-09T20:54Z",
      "summary":"A three-minute conversation.","page":"interviews/buzz-messaging-ai/guy-ben-zvi/index.html",
      "vault":{"endpoint":"https://dev.send.sgraph.ai","id":"w0bf33d4",
               "read_key":"sgit_public_read_334fb47a320489e03adbae82a5b43126aaddc12fdc8676391e53a076568ce4c2",
               "path":"buzz-messaging-ai/guy-ben-zvi/2026-11-09-summit-night/web"}}]}
    """

    @Test("the site's list decodes")
    func decodesList() throws {
        let items = try JSONDecoder().decode(VideoList.self, from: Data(Self.list.utf8)).items
        #expect(items.count == 1)
        #expect(items[0].vault.readKey.hasPrefix("sgit_public_read_"))
        #expect(items[0].folder == "buzz-messaging-ai/guy-ben-zvi/2026-11-09-summit-night/web")
        #expect(items[0].pageURL.absoluteString == "https://promptugal.news/interviews/buzz-messaging-ai/guy-ben-zvi/index.html")
    }

    @Test("the manifest gives init then the segments, in order")
    func manifestOrder() throws {
        let json = #"{"init":"init.mp4","duration":8.0,"segments":[{"file":"seg-000.m4s"},{"file":"seg-001.m4s"}]}"#
        let manifest = try JSONDecoder().decode(VideoManifest.self, from: Data(json.utf8))
        #expect(try manifest.files() == ["init.mp4", "seg-000.m4s", "seg-001.m4s"])
    }

    @Test("a manifest that names a file outside the folder is refused")
    func manifestRefusesPaths() throws {
        let json = #"{"init":"init.mp4","segments":[{"file":"../secret"}]}"#
        let manifest = try JSONDecoder().decode(VideoManifest.self, from: Data(json.utf8))
        #expect(throws: (any Error).self) { try manifest.files() }
        #expect(VideoRules.isPlainName("seg-000.m4s"))
        #expect(!VideoRules.isPlainName(".."))
        #expect(!VideoRules.isPlainName("a/b"))
        #expect(!VideoRules.isPlainName(""))
    }

    @Test("only an https vault server is used")
    func httpsOnly() {
        #expect(VideoRules.server("https://dev.send.sgraph.ai") != nil)
        #expect(VideoRules.server("http://dev.send.sgraph.ai") == nil)
        #expect(VideoRules.server("file:///etc") == nil)
    }

    @Test("the joined file is named after the folder and the progress never passes 100")
    func namesAndProgress() {
        #expect(VideoRules.fileName(folder: "a/b/web") == "a_b_web.mp4")
        #expect(VideoRules.percent(47, 47) == 100)
        #expect(VideoRules.percent(0, 0) == 0)
        #expect(VideoRules.percent(12, 47) == 25)
    }
}
