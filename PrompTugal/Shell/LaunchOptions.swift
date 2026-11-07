import Foundation

/// Launch arguments for screenshots and UI tests, so every screen can be opened directly:
///
///     -PTDestination team.people     open that screen (iPad: in the detail column; iPhone: its tab or More)
///     -PTSampleData                  use the made-up preview data instead of the network
///     -team.me ana                   act as this team member (a UserDefaults argument: it overrides the
///                                    stored value for this launch only and is never written to disk)
///
/// A UI test can loop over `Destinations.all` ids, launch with each, and take a screenshot.
///
/// Debug builds only. In a Release build `arguments` is empty, so none of these work: an App Store or
/// TestFlight build always starts on real data at the saved screen. (The "Try with sample data" button
/// uses `PreviewSamples` directly, not these.)
enum LaunchOptions {
    static var arguments: [String] {
        #if DEBUG
        ProcessInfo.processInfo.arguments
        #else
        []
        #endif
    }

    static func value(_ name: String, in arguments: [String] = arguments) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var destination: String? { value("-PTDestination") }
    static var sampleData: Bool { arguments.contains("-PTSampleData") }

    /// The launched destination when it is not one of the iPhone tabs (so it opens from More).
    @MainActor
    static func launchedMoreDestination(ownsNavigation: Bool) -> AppDestination? {
        guard let id = destination, let destination = Destinations.destination(id),
              destination.phoneTab == nil, destination.ownsNavigation == ownsNavigation else { return nil }
        return destination
    }
}
