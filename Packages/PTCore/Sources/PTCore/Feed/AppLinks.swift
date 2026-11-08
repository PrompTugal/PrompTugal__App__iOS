import Foundation

/// The app's own URL scheme for deep links (`<scheme>://open/<destination>`).
/// The public app uses "promptugal"; the Team app sets "ptteam" once, in its entry point, before any
/// view reads it.
public enum AppLinks {
    /// Set once at launch from the app's entry point; read everywhere else.
    public nonisolated(unsafe) static var scheme = "promptugal"

    /// `<scheme>://open/<destination>`, the form every in-app link takes.
    public static func open(_ destination: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "open"
        parts.path = "/" + destination
        return parts.url
    }
}
