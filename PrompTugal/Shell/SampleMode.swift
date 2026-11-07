import Foundation

/// Sample data: the app filled with made-up people, agents and stories, so anyone without a
/// team key (an App Review reviewer, a new attendee) can see every screen. Turned on from
/// "Try with sample data" on Who are you?, shown with a banner, and turned off from the banner.
/// Works in release builds; it does not depend on launch arguments.
enum SampleMode {
    static let key = "sample.mode"
    /// The "who am I" value for someone not on the team: they get the reader experience.
    static let readerID = "reader"
    /// The made-up person sample mode acts as (see `PreviewSamples`).
    static let samplePersonID = "ana"
    /// "Who am I" before sample mode was turned on, restored when it is left.
    static let previousKey = "sample.previousMe"

    /// Turns sample mode on, keeping the current "who am I" to restore later.
    @MainActor static func enter(defaults: UserDefaults = .standard) {
        defaults.set(defaults.string(forKey: DashboardData.meKey) ?? "", forKey: previousKey)
        defaults.set(samplePersonID, forKey: DashboardData.meKey)
        defaults.set(true, forKey: key)
    }

    /// Turns sample mode off and puts "who am I" back as it was.
    @MainActor static func leave(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: key)
        defaults.set(defaults.string(forKey: previousKey) ?? "", forKey: DashboardData.meKey)
        defaults.removeObject(forKey: previousKey)
    }
}
