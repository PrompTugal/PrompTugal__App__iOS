import Foundation
import Testing
@testable import RiskMandate

@Suite("RiskMandate home")
struct HomeContentTests {
    @Test("the link points at the ABP page")
    func linkTarget() {
        #expect(RiskMandateContent.abpURL.absoluteString == "https://riskmandate.ai/abp.html")
        #expect(RiskMandateContent.abpURL.scheme == "https")
    }
}

@Suite("Command centre address")
struct CommandCentreSettingsTests {
    @Test("the default opens Silvio's X-Ray")
    func defaultAddress() {
        #expect(CommandCentreSettings.defaultURL.absoluteString == "https://web-summit.sgit.ai/people/silvio/app/index.html#xray")
        #expect(CommandCentreSettings.url(from: "").absoluteString == CommandCentreSettings.defaultAddress)
    }

    @Test("only https addresses are accepted")
    func validation() {
        #expect(CommandCentreSettings.validURL("http://example.com") == nil)
        #expect(CommandCentreSettings.validURL("javascript://alert(1)") == nil)
        #expect(CommandCentreSettings.validURL("  ") == nil)
        #expect(CommandCentreSettings.validURL("web-summit.sgit.ai/people/dinis/app/")?.absoluteString
                == "https://web-summit.sgit.ai/people/dinis/app/")
        #expect(CommandCentreSettings.url(from: "ftp://x").absoluteString == CommandCentreSettings.defaultAddress)
    }
}
