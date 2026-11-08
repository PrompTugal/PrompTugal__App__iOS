import Foundation
import Testing
@testable import Team

/// App Review checks the Info.plist against what the app really does (guideline 5.1.1, 2.5.4).
@Suite("Info.plist: purpose strings and background modes")
struct InfoPlistTests {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    @Test("No NFC purpose string: the app has no Core NFC code")
    func noNFC() {
        #expect(info["NFCReaderUsageDescription"] == nil)
    }

    @Test("The camera string is only about scanning a vault key's QR code")
    func camera() throws {
        let text = try #require(info["NSCameraUsageDescription"] as? String)
        #expect(text.contains("QR code"))
        #expect(!text.contains("notes"))
    }

    @Test("The speech string says audio may go to Apple")
    func speech() throws {
        let text = try #require(info["NSSpeechRecognitionUsageDescription"] as? String)
        #expect(text.contains("Apple"))
        #expect(text.contains("on your device"))
    }

    @Test("Every remaining purpose string is one we use")
    func onlyKnownPurposeStrings() {
        let used: Set = ["NSCameraUsageDescription", "NSFaceIDUsageDescription", "NSMicrophoneUsageDescription",
                         "NSSpeechRecognitionUsageDescription", "NSCalendarsWriteOnlyAccessUsageDescription"]
        let declared = Set(info.keys.filter { $0.hasSuffix("UsageDescription") })
        #expect(declared == used)
    }

    @Test("Background modes: fetch only (BGAppRefreshTask), no processing")
    func backgroundModes() {
        #expect(info["UIBackgroundModes"] as? [String] == ["fetch"])
    }

    @Test("Every BGTask identifier is permitted")
    func taskIdentifiers() {
        let permitted = info["BGTaskSchedulerPermittedIdentifiers"] as? [String] ?? []
        #expect(permitted.contains("news.promptugal.team.refresh"))
        #expect(permitted.contains("news.promptugal.team.vault-refresh"))
    }
}
