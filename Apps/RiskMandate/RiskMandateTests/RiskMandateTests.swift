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
