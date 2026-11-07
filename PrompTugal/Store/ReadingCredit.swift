import Foundation

/// The single switch for reading credit (R5). Hidden in Release builds until Dinis decides between a tip
/// ("Support the newsroom") and credit that does something native, because today credit unlocks nothing and
/// App Review would question a purchase with no effect. Debug builds keep it reachable for testing.
///
/// Every place that offers a purchase reads this: the shell's `team.store` destination (design), the top-up sheet
/// a page can request (`AppBridge.meter.topup`), and the "Top up in the app" button injected into promptugal.news.
/// The website's own Stripe top-up stays blocked in every build (guideline 3.1.1), whatever this says.
enum ReadingCredit {
    #if DEBUG
    static let isAvailable = true
    #else
    static let isAvailable = false
    #endif
}
