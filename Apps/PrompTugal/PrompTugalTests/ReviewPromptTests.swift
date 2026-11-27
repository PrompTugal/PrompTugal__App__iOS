import Foundation
import Testing
@testable import PrompTugal

@Suite("Rating prompt")
struct ReviewPromptTests {
    private let installed = Date(timeIntervalSince1970: 1_764_000_000)

    @Test func asksAfterTheThirdReadOnceInstalledTwoDays() {
        let later = installed.addingTimeInterval(3 * 86_400)
        #expect(!ReviewPrompt.shouldAsk(reads: 2, askedVersion: "", version: "0.4.133", firstSeen: installed, now: later))
        #expect(ReviewPrompt.shouldAsk(reads: 3, askedVersion: "", version: "0.4.133", firstSeen: installed, now: later))
    }

    @Test func neverOnTheFirstDaysOrTwiceInOneVersion() {
        let soon = installed.addingTimeInterval(3_600)
        let later = installed.addingTimeInterval(3 * 86_400)
        #expect(!ReviewPrompt.shouldAsk(reads: 5, askedVersion: "", version: "0.4.133", firstSeen: installed, now: soon))
        #expect(!ReviewPrompt.shouldAsk(reads: 5, askedVersion: "0.4.133", version: "0.4.133", firstSeen: installed, now: later))
        #expect(ReviewPrompt.shouldAsk(reads: 5, askedVersion: "0.4.133", version: "0.4.134", firstSeen: installed, now: later))
    }
}
