import Foundation

/// Guideline 3.1.1: inside the app, no web view may open an outside checkout for digital content. One list, used by
/// every web view: `AppBridge.handlesNavigation(to:)` (the website browser and design's `WebPage`) asks it, and any
/// other web view should call `CheckoutPolicy.isBlocked(_:)` in its navigation delegate and cancel.
///
/// Blocked: every Stripe host (`*.stripe.com`, `*.stripe.network`) and the other common hosted checkouts, plus the
/// website's own top-up page. Matching is by host suffix, so `buy.stripe.com`, `checkout.stripe.com` and any new
/// Stripe subdomain are all covered.
enum CheckoutPolicy {
    /// Hosts whose every subdomain is a checkout (matched as the host itself or `*.host`).
    static let blockedHostSuffixes: [String] = [
        "stripe.com", "stripe.network",                         // Stripe Checkout, Payment Links, Elements
        "paypal.com", "paypalobjects.com",                      // PayPal
        "checkout.com",                                         // Checkout.com
        "lemonsqueezy.com", "gumroad.com", "paddle.com",        // merchant-of-record checkouts
        "buymeacoffee.com", "ko-fi.com", "patreon.com",         // tips and memberships
        "squareup.com", "square.link", "checkout.square.site",  // Square
        "pay.google.com", "checkout.shopify.com",               // Google Pay web, Shopify checkout
    ]

    /// Pages on our own sites that start a web payment.
    static let blockedPaths: [(host: String, pathSuffix: String)] = [
        ("promptugal.news", "/account/top-up.html"),
    ]

    static func isBlocked(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty else { return false }
        if blockedHostSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return true }
        return blockedPaths.contains { host == $0.host && url.path.hasSuffix($0.pathSuffix) }
    }
}
