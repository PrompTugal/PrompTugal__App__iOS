import Foundation

/// Reading credit (conductor.a.ios@'s payments worker, appdev.credit@): the app shell injects the charge, so PTPlaces
/// stays PTCore-only. Plain strings: (action, ref, page date, title). Never gates content.
/// Charged here: "story" when one of PrompTugal.news's own articles is opened, and "contribution" when a comment is
/// sent. Not charged: opening a third-party source (we send readers to local media, we do not bill them for it).
@MainActor public enum PlacesCredit {
    /// (action, ref, page date "yyyy-MM-dd" or ISO, title) -> true if a charge was written. Never blocks.
    public static var charge: (String, String, String?, String) -> Bool = { _, _, _, _ in false }
    /// (action, ref, page date) -> "2p" / "free" / "read", or nil to show nothing.
    public static var costText: (String, String, String?) -> String? = { _, _, _ in nil }
}
