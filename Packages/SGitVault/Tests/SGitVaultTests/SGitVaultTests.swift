import CryptoKit
import Foundation
import Testing
@testable import SGitVault

@Suite("SGitVault skeleton")
struct SGitVaultSkeletonTests {
    @MainActor @Test("The traffic log keeps the newest 2,000 events, newest first")
    func trafficLogCap() {
        let log = VaultTrafficLog()
        for index in 0..<(VaultTrafficLog.capacity + 5) {
            log.append(VaultTrafficEvent(kind: .request, path: "bare/data/\(index)"))
        }
        #expect(log.events.count == VaultTrafficLog.capacity)
        #expect(log.events.first?.path == "bare/data/\(VaultTrafficLog.capacity + 4)")
    }

    @Test("The default server is dev.send.sgraph.ai")
    func defaultServer() {
        #expect(VaultAddress(vaultId: "test").server.host() == "dev.send.sgraph.ai")
    }

    @Test("Unimplemented reads throw instead of returning data")
    func notImplemented() async {
        let vault = SGitVault(address: VaultAddress(vaultId: "test"), readKey: SymmetricKey(size: .bits256),
                                    cache: FileManager.default.temporaryDirectory, log: VaultTrafficLog())
        await #expect(throws: VaultError.notImplemented) { try await vault.pull() }
    }
}
