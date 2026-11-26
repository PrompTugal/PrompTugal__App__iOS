// Ported from the Team app's Apps/Team/Sources/Store/CreditStore.swift (same consumables, same "appstore-<id>"
// reference), with the App Store environment recorded on each top-up after VoiceDebrief's Engine/Payments.swift
// (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS, Apache License 2.0).

import Foundation
import Observation
import StoreKit

/// Top-ups of the news app's reading credit with StoreKit 2: the Team app's two consumables. Each verified
/// transaction is written into `LocalCredit`'s ledger and saved before the transaction is finished, so a payment taken
/// is never a credit lost.
///
/// Never a fake purchase: every purchase goes through StoreKit. Run from Xcode with the PrompTugal scheme, StoreKit
/// answers from `Apps/Team/Sources/Store/PrompTugal.storekit` (no money); a TestFlight build buys in the App Store
/// sandbox (no money); only an App Store build takes money. The screen and the history say which.
@MainActor @Observable
public final class LocalTopUps {
    public struct Pack: Identifiable, Sendable, Hashable {
        public let id: String          // the product id
        public let pence: Int
    }

    /// The same product ids as the Team app and `PrompTugal.storekit`.
    public static let packs = [
        Pack(id: "news.promptugal.reader.credit.5", pence: 500),
        Pack(id: "news.promptugal.reader.credit.20", pence: 2_000),
    ]

    public enum Status: Equatable, Sendable {
        case idle, loading, purchasing(String), purchased(pence: Int, test: Bool), pending, cancelled, failed(String)
    }

    /// Where purchases go, as far as StoreKit says it.
    public enum StoreEnvironment: Equatable, Sendable {
        case unknown, xcode, sandbox, production

        public var isTest: Bool { self != .production }

        /// In words for the top-up screen.
        public var words: String {
            switch self {
            case .xcode: return LocalText.string("Test purchases: this build buys from Xcode's StoreKit test file. No money is taken.")
            case .sandbox: return LocalText.string("Test purchases: this build buys in the App Store sandbox (TestFlight). No money is taken.")
            case .production: return LocalText.string("Purchases are real and charged by the App Store.")
            case .unknown: return Self.unknownWords
            }
        }

        #if DEBUG
        static let unknownWords = LocalText.string("Debug build: purchases go to the StoreKit test file or the App Store sandbox. No money is taken.")
        #else
        static let unknownWords = LocalText.string("Purchases are charged by the App Store, unless this is a TestFlight build (sandbox, no money).")
        #endif
    }

    public private(set) var products: [Product] = []
    public private(set) var status: Status = .idle
    public private(set) var unavailable = false
    public private(set) var environment: StoreEnvironment = .unknown

    @ObservationIgnored weak var credit: LocalCredit?
    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {}

    /// Takes transactions finished elsewhere (Ask to Buy, an interrupted purchase). Called by `LocalCredit.start()`.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.handle(result) }
        }
        Task { [weak self] in
            for await result in Transaction.unfinished { await self?.handle(result) }
        }
        Task { [weak self] in await self?.readEnvironment() }
    }

    /// The app's own transaction says whether this build talks to Xcode, the sandbox or the App Store.
    func readEnvironment() async {
        guard let result = try? await AppTransaction.shared else { return }
        switch result {
        case .verified(let app), .unverified(let app, _):
            environment = Self.environment(app.environment)
        }
    }

    nonisolated static func environment(_ value: AppStore.Environment) -> StoreEnvironment {
        switch value {
        case .production: .production
        case .sandbox: .sandbox
        case .xcode: .xcode
        default: .unknown
        }
    }

    public func loadProducts() async {
        guard products.isEmpty else { return }
        status = .loading
        do {
            let loaded = try await Product.products(for: Self.packs.map(\.id))
            products = loaded.sorted { $0.price < $1.price }
            unavailable = loaded.isEmpty
            status = .idle
        } catch {
            unavailable = true
            status = .failed(LocalText.string("The App Store could not be reached."))
        }
    }

    public func pence(for product: Product) -> Int {
        Self.packs.first { $0.id == product.id }?.pence ?? 0
    }

    public func purchase(_ product: Product) async {
        status = .purchasing(product.id)
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending:
                status = .pending
            case .userCancelled:
                status = .cancelled
            @unknown default:
                status = .idle
            }
        } catch {
            status = .failed(LocalText.string("The purchase did not complete."))
        }
    }

    /// Refunds: reading credit unlocks nothing (every page opens at any balance), so a refund is not taken back from
    /// the ledger. A transaction that arrives already revoked is not credited, and is finished.
    func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            status = .failed(LocalText.string("The App Store could not verify this purchase, so no credit was added."))
            return                                  // not finished: an unverified transaction is left to StoreKit
        }
        guard transaction.productType == .consumable,
              let pack = Self.packs.first(where: { $0.id == transaction.productID }) else {
            await transaction.finish()              // not ours to credit
            return
        }
        guard transaction.revocationDate == nil else {
            await transaction.finish()
            return
        }
        let env = Self.environment(transaction.environment)
        let pence = pack.pence * max(1, transaction.purchasedQuantity)
        guard let credit else { return }            // not finished: offered again at the next launch
        do {
            try credit.addTopUp(micro: CreditMoney.micro(pence: Double(pence)), ref: Self.reference(for: transaction.id),
                                source: Self.source(env))
        } catch {
            status = .failed(LocalText.string("Your credit could not be saved on this device. It will be added the next time the app opens."))
            return                                  // not finished: StoreKit offers it again (Transaction.unfinished)
        }
        if environment == .unknown { environment = env }
        status = .purchased(pence: pence, test: env.isTest)
        await transaction.finish()                  // only now that the credit is saved
    }

    /// The reference the ledger keeps for one App Store transaction (the Team app's, so the two never double-count).
    public nonisolated static func reference(for transactionID: UInt64) -> String { "appstore-\(transactionID)" }

    nonisolated static func source(_ env: StoreEnvironment) -> String {
        switch env {
        case .production: "appstore:production"
        case .sandbox: "appstore:sandbox"
        case .xcode: "appstore:xcode"
        case .unknown: "appstore:unknown"
        }
    }
}
