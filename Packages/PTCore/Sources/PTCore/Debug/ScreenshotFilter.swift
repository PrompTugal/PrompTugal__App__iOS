import Foundation

/// A screenshot-only filter: launch with `-PTHideTerm "<term>"` (UserDefaults key `PTHideTerm`) and every agenda
/// event whose title or place contains the term, and every news item whose title contains it, is left out of what
/// the screens show. Case-insensitive. Debug builds only: in Release `activeTerm` is always nil, so nothing is
/// ever filtered.
public enum ScreenshotFilter {
    public static let key = "PTHideTerm"

    /// The term to hide, or nil (always nil in Release).
    public static var activeTerm: String? {
        #if DEBUG
        let term = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (term?.isEmpty ?? true) ? nil : term
        #else
        return nil
        #endif
    }

    /// False when any of the texts contains the term (case-insensitive); true when there is no term.
    public static func keep(_ texts: String..., hiding term: String? = activeTerm) -> Bool {
        guard let term, !term.isEmpty else { return true }
        return !texts.contains { $0.localizedCaseInsensitiveContains(term) }
    }

    public static func events(_ events: [Event], hiding term: String? = activeTerm) -> [Event] {
        guard term != nil else { return events }
        return events.filter { keep($0.title, $0.place, hiding: term) }
    }

    public static func stories(_ stories: [Story], hiding term: String? = activeTerm) -> [Story] {
        guard term != nil else { return stories }
        return stories.filter { keep($0.title, hiding: term) }
    }
}
