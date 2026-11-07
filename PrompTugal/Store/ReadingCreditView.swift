import StoreKit
import SwiftUI

/// Entry view for reading credit: the website's meter balance, shown natively, and the native top-up (D6).
struct ReadingCreditView: View {
    @Environment(MeterStore.self) private var meter
    @Environment(CreditStore.self) private var credits
    @Environment(\.dismiss) private var dismiss
    /// True when shown as the top-up sheet a page asked for; then it has a Done button.
    var showsDone = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading credit").font(.caption).foregroundStyle(.secondary)
                    Text(meter.snapshot.map { MeterStore.money($0.balance) } ?? "Not yet read")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    if let snapshot = meter.snapshot {
                        Text("\(snapshot.reads) pages read · \(MeterStore.money(snapshot.spent)) spent · \(snapshot.topups) top-ups")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Read from promptugal.news at \(Lisbon.timeLabel(snapshot.readAt)), Lisbon time.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Open promptugal.news in the app once to read your balance.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                if !meter.pendingCredits.isEmpty {
                    Label("\(MeterStore.money(Double(meter.pendingCredits.reduce(0) { $0 + $1.pence }))) paid, added when promptugal.news next opens in the app",
                          systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                }
            }

            Section {
                if credits.products.isEmpty {
                    if credits.unavailable {
                        Text("Top-ups are not available from the App Store yet.").foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }
                ForEach(credits.products, id: \.id) { product in
                    Button {
                        Task { await credits.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(MeterStore.money(Double(credits.pence(for: product)))) of reading credit")
                                    .foregroundStyle(.primary)
                                Text(product.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if credits.status == .purchasing(product.id) {
                                ProgressView()
                            } else {
                                Text(product.displayPrice).bold()
                            }
                        }
                    }
                    .disabled(credits.status == .purchasing(product.id))
                }
                statusLine
            } header: {
                Text("Top up")
            } footer: {
                Text("Credit goes to the reading meter in this app’s copy of promptugal.news, as a top-up on the website would. Every page still opens at any balance.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reading credit")
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .task { await credits.loadProducts() }
    }

    @ViewBuilder private var statusLine: some View {
        switch credits.status {
        case .purchased(let pence):
            Label("Thank you: \(MeterStore.money(Double(pence))) added.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .pending:
            Label("Waiting for approval.", systemImage: "hourglass")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }
}
