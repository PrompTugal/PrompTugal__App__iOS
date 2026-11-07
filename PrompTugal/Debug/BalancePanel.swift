import Charts
import SwiftUI

/// Debug → Balance: how much of the app is native, web or hybrid, screen by screen,
/// so the team can see the balance it is learning.
struct BalancePanel: View {
    private var destinations: [AppDestination] { Destinations.all }

    var body: some View {
        let groups = Dictionary(grouping: destinations, by: { $0.kind.label })
        let counts = ["Native", "Hybrid", "Web"].map { (kind: $0, count: groups[$0]?.count ?? 0) }
        List {
            Section {
                Chart(counts, id: \.kind) { item in
                    BarMark(x: .value("Screens", item.count), y: .value("Kind", "Screens"))
                        .foregroundStyle(by: .value("Kind", item.kind))
                }
                .chartForegroundStyleScale(["Native": Palette.green, "Hybrid": Palette.amber, "Web": Palette.blue])
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 56)
                Text(counts.map { "\($0.count) \($0.kind.lowercased())" }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Palette.muted)
            } footer: {
                Text("Every screen in the sidebar, by how it is built. Web screens open the website inside the app; native screens are SwiftUI over the same public data.")
            }
            ForEach(ShellSection.allCases) { section in
                let rows = destinations.filter { $0.section == section }
                if !rows.isEmpty {
                    Section(section.rawValue) {
                        ForEach(rows) { destination in
                            HStack {
                                Label(destination.title, systemImage: destination.symbol)
                                Spacer()
                                KindBadge(kind: destination.kind)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Native and web")
    }
}
