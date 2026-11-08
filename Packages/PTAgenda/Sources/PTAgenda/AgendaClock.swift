import Foundation

/// The one clock of the agenda screens. `override` is for DEBUG launches that pretend it is another time
/// (`-PTNow`, for App Store screenshots and tests); in a Release build nothing sets it, so it is the real time.
public enum AgendaClock {
    nonisolated(unsafe) public static var override: Date?
    public static var now: Date { override ?? Date() }
}
