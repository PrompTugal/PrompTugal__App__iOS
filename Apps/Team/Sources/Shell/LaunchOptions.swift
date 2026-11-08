import Foundation

/// Launch arguments for screenshots and UI tests, so every screen can be opened directly:
///
///     -PTDestination team.people     open that screen (iPad: in the detail column; iPhone: its tab or More)
///     -PTSampleData                  use the made-up preview data instead of the network
///     -PTMe ana                      act as this team member
///
/// A UI test can loop over `Destinations.all` ids, launch with each, and take a screenshot.
/// Debug builds only: in a release build every option reads as absent. A reviewer turns on sample
/// data from the app itself ("Try with sample data" on Who are you?), see `SampleMode`.
enum LaunchOptions {
    static var arguments: [String] {
        #if DEBUG
        ProcessInfo.processInfo.arguments
        #else
        []
        #endif
    }

    static func value(_ name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var destination: String? { value("-PTDestination") }
    static var me: String? { value("-PTMe") }
    static var sampleData: Bool { arguments.contains("-PTSampleData") }

    /// The launched destination when it is not one of the iPhone tabs (so it opens from More).
    @MainActor
    static func launchedMoreDestination(ownsNavigation: Bool) -> AppDestination? {
        guard let id = destination, let destination = Destinations.destination(id),
              destination.phoneTab == nil, destination.ownsNavigation == ownsNavigation else { return nil }
        return destination
    }
}
