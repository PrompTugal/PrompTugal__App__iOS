import Foundation
import Testing
@testable import PTCore

@Suite("Build info decoding")
struct BuildInfoDecodingTests {
    @Test("Empty optional fields read as nil")
    func decodesEmptyFields() throws {
        let json = #"""
        {"commit":"0123456789abcdef0123456789abcdef01234567","shortCommit":"0123456","branch":"dev","dirty":false,
         "commitDate":"","commitCount":3,"siteRelease":"v0.1.3","builtAt":"2026-11-08T03:00:00Z",
         "builder":"local","ciRun":"","configuration":"Debug"}
        """#
        let info = try #require(BuildInfo.decode(Data(json.utf8)))
        #expect(info.commitDate == nil)
        #expect(info.ciRun == nil)
        #expect(info.commitURL?.absoluteString.hasSuffix("/commit/0123456789abcdef0123456789abcdef01234567") == true)
    }

    @Test("Unknown build has no commit link")
    func unknown() {
        #expect(BuildInfo.unknown.commitURL == nil)
        #expect(BuildInfo.decode(Data("not json".utf8)) == nil)
    }
}
