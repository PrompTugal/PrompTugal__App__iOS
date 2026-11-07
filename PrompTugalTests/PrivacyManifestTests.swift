import Foundation
import Testing
@testable import PrompTugal

@Suite("Privacy manifest")
struct PrivacyManifestTests {
    @Test("PrivacyInfo.xcprivacy ships in the app and declares the required-reason APIs we use")
    func manifest() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                               "PrivacyInfo.xcprivacy is not in the app bundle (App Store Connect rejects the upload)")
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url),
                                                                             format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let types = (plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? [])
            .compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        #expect(types.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(types.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
    }
}
