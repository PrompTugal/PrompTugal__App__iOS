import Foundation
import Testing
@testable import PTWeb

// The bridge's gate (S7, Q10) and the checkout block (3.1.1), moved from the app's AppReviewTests with the bridge.
// Each rule has a control next to it: the same input that is allowed, so a test cannot pass by refusing everything.

// MARK: - Bridge gate

@Suite("Bridge gate")
struct BridgeGateTests {
    private func gate(_ scheme: String = "https", host: String = "promptugal.news", port: Int = 0,
                      main: Bool = true, op: String = "schedule.get") -> AppBridge.Gate {
        AppBridge.gate(scheme: scheme, host: host, port: port, isMainFrame: main, op: op)
    }

    @Test func theRightPageMayCallEveryPublicOp() {
        for op in AppBridge.ops { #expect(gate(op: op) == .allowed, "\(op)") }
        #expect(gate(port: 443) == .allowed)
        #expect(gate(host: "PROMPTUGAL.NEWS") == .allowed)
    }

    @Test func wrongHostIsRefused() {
        #expect(gate(host: "evil.example") != .allowed)
        #expect(gate(host: "promptugal.news.evil.example") != .allowed)
        #expect(gate(host: "sub.promptugal.news") != .allowed)
    }

    @Test func iframeIsRefused() {
        #expect(gate(main: false) != .allowed)
    }

    @Test func plainHTTPIsRefused() {
        #expect(gate("http") != .allowed)
        #expect(gate("file", host: "") != .allowed)
    }

    @Test func aPortOtherThan443IsRefused() {
        #expect(gate(port: 8443) != .allowed)
        #expect(gate(port: 80) != .allowed)
    }

    @Test func anUnknownOpIsRefused() {
        #expect(gate(op: "vault.load") == .refused(reason: "unknown op", message: "Unknown op vault.load."))
        #expect(gate(op: "") != .allowed)
    }

    @Test func theScheduleAndMeterBelongToPromptugalNewsOnly() {
        for op in ["schedule.get", "schedule.set", "schedule.pageChanged", "meter.topup", "meter.pageChanged"] {
            #expect(gate(host: "web-summit.sgit.ai", op: op) != .allowed, "\(op)")
        }
        // control: the team site may still ask who I am and plan reminders
        #expect(gate(host: "web-summit.sgit.ai", op: "identity.get") == .allowed)
        #expect(gate(host: "web-summit.sgit.ai", op: "notify.plan") == .allowed)
    }
}

// MARK: - Checkout block (3.1.1)

@Suite("Checkout block")
struct CheckoutPolicyTests {
    @Test func everyStripeHostIsBlocked() throws {
        for text in ["https://buy.stripe.com/6oU", "https://checkout.stripe.com/c/pay/cs_1", "https://stripe.com/",
                     "https://js.stripe.com/v3", "https://m.stripe.network/inner.html", "https://BUY.STRIPE.COM/x"] {
            #expect(CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func otherCheckoutsAndOurTopUpPageAreBlocked() throws {
        for text in ["https://www.paypal.com/checkoutnow", "https://buymeacoffee.com/x", "https://x.lemonsqueezy.com/buy",
                     "https://promptugal.news/account/top-up.html"] {
            #expect(CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func ordinaryPagesAreNotBlocked() throws {
        for text in ["https://promptugal.news/account/index.html", "https://promptugal.news/events/x/index.html",
                     "https://web-summit.sgit.ai/", "https://notstripe.com/", "https://stripe.com.evil.example/"] {
            #expect(!CheckoutPolicy.isBlocked(try #require(URL(string: text))), "\(text)")
        }
    }

    @Test func releaseTopUpScriptOffersNoAppPurchase() {
        let release = BridgeScripts.hideWebTopUp(offerAppTopUp: false)
        let debug = BridgeScripts.hideWebTopUp(offerAppTopUp: true)
        #expect(release.contains("const offer = false"))
        #expect(debug.contains("const offer = true"))
        #expect(!release.contains("__OFFER__"))
        // both hide the website's Stripe top-up
        #expect(release.contains(#"a[href*="buy.stripe.com"]"#) && debug.contains(#"a[href*="buy.stripe.com"]"#))
    }
}
