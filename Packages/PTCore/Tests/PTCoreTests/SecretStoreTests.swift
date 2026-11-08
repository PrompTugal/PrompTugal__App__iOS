import Foundation
import Testing
@testable import PTCore

@Suite("Secret store")
struct SecretStoreTests {
    @Test("The memory store writes, reads, counts reads and deletes")
    func memoryRoundTrip() throws {
        let store = MemorySecretStore(["a": "1"])
        #expect(try store.read("a") == "1")
        try store.write("2", account: "b")
        #expect(try store.read("b") == "2")
        #expect(store.reads == 2)
        try store.delete("a")
        #expect(try store.read("a") == nil)
    }

    @Test("A Keychain store keeps the service it was given")
    func keychainService() {
        #expect(KeychainSecretStore(service: "news.promptugal.reader.ai").service == "news.promptugal.reader.ai")
        #expect(SecretStoreError.keychain(-25300).errorDescription == "Keychain error -25300")
    }
}
