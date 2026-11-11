import Foundation
import Testing
@testable import Fringe

@Suite("Lisbon Fringe app")
struct FringeAppTests {
    @Test("the bundle is news.promptugal.fringe and the name is Lisbon Fringe")
    func identity() {
        #expect(Bundle.main.bundleIdentifier == "news.promptugal.fringe")
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Lisbon Fringe")
    }

    @Test("Info.plist asks for no camera, microphone, speech, Face ID or location, and only the calendar string")
    func purposeStrings() {
        let info = Bundle.main.infoDictionary ?? [:]
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
                    "NSFaceIDUsageDescription", "NSLocationWhenInUseUsageDescription", "NSContactsUsageDescription"] {
            #expect(info[key] == nil, "\(key) must not be set")
        }
        #expect(info["NSCalendarsWriteOnlyAccessUsageDescription"] != nil)
    }

    @Test("the privacy manifest says Data Not Collected and no tracking")
    func privacyManifest() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }

    @Test("the independence line says not affiliated with Web Summit")
    func independence() {
        #expect(FringeText.independence.contains("not affiliated"))
        #expect(FringeText.independence.contains("Web Summit"))
    }
}
