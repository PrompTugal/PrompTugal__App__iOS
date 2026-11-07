import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import PrompTugal

/// Does StoreKit testing answer in this test run? Prints what it finds (`STOREKIT-PROBE …` in the log), so CI
/// shows which setup gives products: the scheme's Test action StoreKit configuration (the app host starts in
/// the StoreKit test environment) and/or an `SKTestSession` made from the .storekit file. Records nothing as a
/// failure: team's `CreditStoreTests` hold the real purchase checks.
@Suite("StoreKit test environment", .serialized)
@MainActor
struct StoreKitEnvironmentTests {
    static let ids = ["news.promptugal.reader.credit.5", "news.promptugal.reader.credit.20"]

    @Test("Products before any SKTestSession (scheme Test action configuration)")
    func schemeConfiguration() async {
        do {
            let products = try await Product.products(for: Self.ids)
            print("STOREKIT-PROBE scheme-only products=\(products.count) ids=\(products.map(\.id).sorted())")
        } catch {
            print("STOREKIT-PROBE scheme-only error=\(error)")
        }
    }

    @Test("Products with an SKTestSession from the .storekit file")
    func testSession() async throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrompTugal/Store/PrompTugal.storekit")
        let session = try SKTestSession(contentsOf: file)
        session.disableDialogs = true
        do {
            let products = try await Product.products(for: Self.ids)
            print("STOREKIT-PROBE session products=\(products.count) prices=\(products.map(\.displayPrice).sorted())")
        } catch {
            print("STOREKIT-PROBE session error=\(error)")
        }
        let signed = Bundle.main.bundleURL.appendingPathComponent("_CodeSignature").path
        print("STOREKIT-PROBE host=\(Bundle.main.bundleIdentifier ?? "?") signed=\(FileManager.default.fileExists(atPath: signed))")
        withExtendedLifetime(session) {}
    }
}
