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

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            status = .failed("The App Store could not verify this purchase.")
            return
        }
        guard transaction.productType == .consumable,
              let pack = Self.packs.first(where: { $0.id == transaction.productID }) else {
            await transaction.finish()
            return
        }
        if transaction.revocationDate == nil {
            meter.addCredit(reference: "appstore-\(transaction.id)", pence: pack.pence * transaction.purchasedQuantity,
                            productID: pack.id)
            status = .purchased(pack.pence * transaction.purchasedQuantity)
        }
        // Finished only after the credit is saved on the device, so a crash here repeats the transaction instead of losing it.
        await transaction.finish()
    }
}
