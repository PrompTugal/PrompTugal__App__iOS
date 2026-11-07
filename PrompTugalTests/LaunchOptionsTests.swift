import Foundation
import Testing
@testable import PrompTugal

@Suite("Launch options (Debug builds only)")
struct LaunchOptionsTests {
    @Test("A value is the argument after its name")
    func value() {
        let arguments = ["/app", "-PTDestination", "team.people", "-PTSampleData"]
        #expect(LaunchOptions.value("-PTDestination", in: arguments) == "team.people")
        #expect(LaunchOptions.value("-PTSampleData", in: arguments) == nil)
        #expect(LaunchOptions.value("-PTMissing", in: arguments) == nil)
    }

    @Test("Debug builds read the process arguments; Release builds read none")
    func debugOnly() {
        #if DEBUG
        #expect(LaunchOptions.arguments == ProcessInfo.processInfo.arguments)
        #else
        #expect(LaunchOptions.arguments.isEmpty)
        #endif
    }
}
