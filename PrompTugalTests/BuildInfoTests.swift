import Foundation
import Testing
@testable import PrompTugal

@Suite("Build info")
struct BuildInfoTests {
    @Test("The build phase put BuildInfo.json in the app bundle")
    func bundled() {
        let info = BuildInfo.load(from: .main)
        #expect(info != .unknown)
        #expect(info.siteRelease.hasPrefix("v"))
        #expect(info.commit.count == 40)
    }
}
