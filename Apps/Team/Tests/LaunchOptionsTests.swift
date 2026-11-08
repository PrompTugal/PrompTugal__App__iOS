import Foundation
import Testing
@testable import Team

@Suite("Launch options (Debug builds only)")
struct LaunchOptionsTests {
    @Test("Debug builds read the process arguments; Release builds read none")
    func debugOnly() {
        #if DEBUG
        #expect(LaunchOptions.arguments == ProcessInfo.processInfo.arguments)
        #else
        #expect(LaunchOptions.arguments.isEmpty)
        #endif
    }
}
