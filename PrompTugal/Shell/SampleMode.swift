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
}
