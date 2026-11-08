import Foundation

/// What the host app supplies to Lanes. The Team app sets `linkedVaults` from its coordination store
/// (teammates' vault ids by name). Default: none, so Lanes never names a team type.
@MainActor
public enum LanesEnvironment {
    public static var linkedVaults: @MainActor () -> [String: String] = { [:] }
}
