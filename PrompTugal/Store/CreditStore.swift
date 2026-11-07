import Foundation
import Observation
import StoreKit

/// Native top-up of the reading meter with StoreKit 2 (decision D6). Two consumables; each verified transaction is
/// recorded in `MeterStore` as pending credit, finished, and then written into the website's meter by the bridge.
///
/// Apple setup needed before this works outside Xcode: the two consumables in App Store Connect with these ids, the
/// Paid Apps agreement signed, and the In-App Purchase capability. For local testing, the platform session adds a
/// `.storekit` configuration with the same ids to the scheme.
@MainActor @Observable
final class CreditStore {
    struct Pack: Identifiable, Sendable, Hashable {
        let id: String          // the product id
        let pence: Int
    }

    static let packs = [
        Pack(id: "news.promptugal.reader.credit.5", pence: 500),
        Pack(id: "news.promptugal.reader.credit.20", pence: 2_000),
    ]

    enum Status: Equatable {
        case idle, loading, purchasing(String), purchased(Int), pending, cancelled, failed(String)
    }

    private(set) var products: [Product] = []
    private(set) var status: Status = .idle
    private(set) var unavailable = false

    @ObservationIgnored private let meter: MeterStore
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(meter: MeterStore) {
        self.meter = meter
    }

    /// Call once at launch: takes transactions finished elsewhere (Ask to Buy, an interrupted purchase).
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.handle(result) }
        }
        Task { [weak self] in
            for await result in Transaction.unfinished { await self?.handle(result) }
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        status = .loading
        do {
            let loaded = try await Product.products(for: Self.packs.map(\.id))
            products = loaded.sorted { $0.price < $1.price }
            unavailable = loaded.isEmpty
            status = .idle
        } catch {
            unavailable = true
            status = .failed("The App Store could not be reached.")
        }
    }

    func pence(for product: Product) -> Int {
        Self.packs.first { $0.id == product.id }?.pence ?? 0
    }

    func purchase(_ product: Product) async {
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
            status = .failed("The purchase did not complete.")
        }
    }

    /// Refunds and revocations (policy, Q3/S7): reading credit unlocks nothing (every page opens at any balance), so
    /// a refund is not taken back from the website's meter. A transaction that arrives already revoked is not
    /// credited, and is finished. Apple's refund handles the money; the app keeps no record beyond the transaction id.
    func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            status = .failed("The App Store could not verify this purchase.")
            return                                  // not finished: an unverified transaction is left to StoreKit
        }
        guard transaction.productType == .consumable,
              let pack = Self.packs.first(where: { $0.id == transaction.productID }) else {
            await transaction.finish()              // not ours to credit
            return
        }
        guard transaction.revocationDate == nil else {
            await transaction.finish()              // refunded or revoked before it was credited: nothing to add
            return
        }
        let pence = pack.pence * max(1, transaction.purchasedQuantity)
        do {
            try meter.addCredit(reference: Self.reference(for: transaction.id), pence: pence, productID: pack.id)
        } catch {
            // Not finished: StoreKit offers the transaction again (Transaction.unfinished at the next launch).
            status = .failed("Your credit could not be saved on this device. It will be added the next time the app opens.")
            return
        }
        status = .purchased(pence)
        await transaction.finish()                  // only now that the credit is saved on the device
    }

    /// The reference the website's meter keeps for one App Store transaction.
    nonisolated static func reference(for transactionID: UInt64) -> String { "appstore-\(transactionID)" }
}
