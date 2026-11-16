// The chip and the credit screen follow VoiceDebrief's UI/CreditView.swift
// (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS, Apache License 2.0).

import PTCore
import StoreKit
import SwiftUI

// MARK: - The balance, always in sight

/// The balance in a small capsule. It changes as things are charged and opens the credit screen. Below zero it turns
/// amber and nothing else happens: no banner, nothing blocked (as on promptugal.news).
public struct CreditChip: View {
    @State private var credit = LocalCredit.shared
    @State private var showing = false
    /// Compact: the amount alone, for tight headers such as the Places home.
    let compact: Bool

    public init() { compact = false }

    /// `CreditChip(compact: true)`: the smallest form, for the Places home (the app shell places it).
    public init(compact: Bool) { self.compact = compact }

    public var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                if !compact { Image(systemName: "sterlingsign.circle") }
                Text(credit.balanceText)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(credit.balance)))
            }
            .font(.caption.weight(.semibold))
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(credit.isBelowZero ? Palette.amber : Palette.ink)
            .background((credit.isBelowZero ? Palette.amber : Palette.muted).opacity(0.14), in: Capsule())
            .animation(.snappy, value: credit.balance)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reading credit: \(credit.balanceText)")
        .accessibilityHint(credit.isBelowZero ? "Below zero. Nothing is blocked. Opens your credit." : "Opens your credit and its history.")
        .sheet(isPresented: $showing) {
            NavigationStack {
                LocalCreditView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showing = false } }
                    }
            }
        }
    }
}

/// What an action costs, shown before it is spent: "2p", "free", or "read" when already paid this session.
public struct CostTag: View {
    @State private var credit = LocalCredit.shared
    let kind: CreditKind

    public init(_ kind: CreditKind) { self.kind = kind }

    public var body: some View {
        let text = credit.costText(of: kind)
        Text(text)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 5).padding(.vertical, 1)
            .foregroundStyle(credit.wouldCharge(kind) ? Palette.blue : Palette.muted)
            .overlay(Capsule().strokeBorder(Palette.muted.opacity(0.35)))
            .accessibilityLabel(text == "read" ? "Already paid for" : "Costs \(text)")
    }
}

public extension View {
    /// Charges the kind once when this screen appears (once per session for a page, as the site does).
    func chargesCredit(_ kind: CreditKind?) -> some View {
        task(id: kind?.id) { @MainActor in
            if let kind { LocalCredit.shared.charge(kind: kind) }
        }
    }
}

// MARK: - The credit screen

/// The balance, top-ups, every charge newest first, and the price list (the site's).
public struct LocalCreditView: View {
    @State private var credit = LocalCredit.shared
    @State private var declining: CreditEntry?

    public init() {}

    private var topUps: LocalTopUps { credit.topUps }

    public var body: some View {
        List {
            balance
            topUpSection
            outletsSection
            historySection
            pricesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reading credit")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await topUps.loadProducts()
            await credit.refreshPrices()
        }
        .confirmationDialog("Don't charge me for this", isPresented: decliningBinding, titleVisibility: .visible,
                            presenting: declining) { entry in
            ForEach(CreditBook.declineReasons, id: \.self) { reason in
                Button(reason) { credit.decline(entry, reason: reason) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("\(credit.money(-entry.amount)) back for “\(entry.text)”, and the reason kept in your history on this device.")
        }
    }

    private var decliningBinding: Binding<Bool> {
        Binding(get: { declining != nil }, set: { if !$0 { declining = nil } })
    }

    private var balance: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reading credit").font(.caption).foregroundStyle(.secondary)
                Text(credit.balanceText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(credit.isBelowZero ? Palette.amber : Palette.ink)
                    .contentTransition(.numericText(value: Double(credit.balance)))
                Text("\(credit.book.reads) things read · \(credit.money(credit.book.spent)) spent · \(credit.money(credit.book.toppedUp)) topped up")
                    .font(.footnote).foregroundStyle(.secondary)
                if credit.isBelowZero {
                    Text("Below zero: nothing is blocked. Top up when you like.")
                        .font(.footnote).foregroundStyle(Palette.amber)
                }
                if let problem = credit.problem {
                    Label(problem, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Every story, town and AI answer in the app costs what the same kind of page costs on promptugal.news. You start with \(credit.money(credit.startingCredit)), as on the site. The history is kept on this device only.")
        }
    }

    // MARK: Top up

    private var topUpSection: some View {
        Section {
            if topUps.products.isEmpty {
                if topUps.unavailable {
                    Text("Top-ups are not available from the App Store yet.").foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            ForEach(topUps.products, id: \.id) { product in
                Button {
                    Task { await topUps.purchase(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(credit.money(CreditMoney.micro(pence: Double(topUps.pence(for: product))))) of reading credit")
                                .foregroundStyle(.primary)
                            Text(product.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if topUps.status == .purchasing(product.id) {
                            ProgressView()
                        } else {
                            Text(product.displayPrice).bold()
                        }
                    }
                }
                .disabled(topUps.status == .purchasing(product.id))
            }
            statusLine
        } header: {
            Text("Top up")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if topUps.environment.isTest {
                    Label(topUps.environment.words, systemImage: "testtube.2").foregroundStyle(Palette.amber)
                } else {
                    Text(topUps.environment.words)
                }
                Text("A top-up adds to the balance on this device. Nothing renews.")
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch topUps.status {
        case .purchased(let pence, let test):
            Label(test ? "Test purchase: \(credit.money(CreditMoney.micro(pence: Double(pence)))) added, no money taken."
                       : "Thank you: \(credit.money(CreditMoney.micro(pence: Double(pence)))) added.",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .pending:
            Label("Waiting for approval.", systemImage: "hourglass")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    // MARK: Where your credit goes

    private var outletsSection: some View {
        Section {
            let lines = credit.byOutlet
            if lines.isEmpty {
                Text("Nothing yet. Stories you pay to read show here, by the outlet that published them.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.outlet)
                        Text(outletDetail(line)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(credit.money(line.worth)).monospacedDigit()
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        } header: {
            HStack {
                Text("Where your credit goes")
                Spacer()
                PlannedBadge()
            }
        } footer: {
            Text("What your reading of each outlet's stories was worth on this device. Sharing reading revenue with the local media whose stories you read is planned, not yet in place: no money has been sent to any outlet.")
        }
    }

    private func outletDetail(_ line: OutletLine) -> String {
        let reads = line.reads == 1 ? "1 paid read" : "\(line.reads) paid reads"
        return line.declined == 0 ? reads : "\(reads), \(line.declined) not charged"
    }

    // MARK: History

    private var historySection: some View {
        Section("History") {
            ForEach(credit.history.prefix(200)) { entry in
                CreditEntryRow(entry: entry, declined: credit.isDeclined(entry), symbol: credit.symbol)
                    .swipeActions {
                        if entry.kind == .charge && !credit.isDeclined(entry) {
                            Button("Don't charge me") { declining = entry }.tint(.orange)
                        }
                    }
            }
        }
    }

    // MARK: Prices

    private var pricesSection: some View {
        Section {
            ForEach(CreditKind.priceList, id: \.label) { row in
                HStack {
                    Text(row.label)
                    Spacer()
                    Text(CreditMoney.price(credit.cost(of: row.kind), symbol: credit.symbol))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Link(destination: LocalCredit.pricesPage) {
                Label("How the site prices a page", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("What things cost")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("From promptugal.news's meter (\(credit.config.meter ?? "sg-meter"), \(credit.config.version ?? "built in")): price by kind of page and how fresh it is, never less than \(CreditMoney.price(CreditMoney.micro(pence: credit.config.floor))). Reading the same thing again in one session is not charged twice. Swipe a charge to say why you won't pay for it.")
                ProvenanceLabel(provenance: credit.priceProvenance, phase: .loaded)
            }
        }
    }
}

struct CreditEntryRow: View {
    let entry: CreditEntry
    let declined: Bool
    let symbol: String

    private func money(_ micro: Int) -> String { CreditMoney.money(micro, symbol: symbol) }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text).lineLimit(2).strikethrough(declined)
                HStack(spacing: 6) {
                    Text(entry.at, format: .dateTime.day().month().hour().minute())
                    if let outlet = entry.outlet { Text(outlet) }
                    if let type = entry.pageType { Text(type + (entry.tier.map { " · \($0)" } ?? "")) }
                    if let reason = entry.reason { Text(reason) }
                }
                .font(.caption).foregroundStyle(.secondary)
                if entry.isTestPurchase {
                    Label("Test purchase: no money taken", systemImage: "testtube.2")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Palette.amber)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((entry.amount > 0 ? "+" : "") + money(entry.amount)).monospacedDigit()
                Text(money(entry.balance)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch entry.kind {
        case .start: "gift"
        case .charge: "book"
        case .topUp: "plus.circle"
        case .refund: "arrow.uturn.backward"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case .charge: Palette.muted
        case .topUp, .start: .green
        case .refund: .orange
        }
    }
}

/// Marks a figure that describes a plan, not something done: payouts to outlets are not made yet.
public struct PlannedBadge: View {
    public init() {}
    public var body: some View {
        Label("Planned, not yet paid", systemImage: "calendar.badge.clock")
            .font(.caption2.weight(.bold))
            .textCase(nil)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(Palette.amber)
            .background(Palette.amber.opacity(0.14), in: Capsule())
            .accessibilityLabel("Planned, not yet paid: no money has been sent to outlets")
    }
}
