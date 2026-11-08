import SwiftUI

/// The team's check-ins, native: each person's morning, midday or evening note, newest day first, and the pulse
/// agent's summary one tap away. From the team site's `/pulse/` twin.
struct PulseView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity

    /// The check-ins themselves: entries whose slot starts with a date ("2026-11-03-morning"), not a person's overview.
    private var checkIns: [PulseEntry] {
        team.pulse.filter { Self.isDated($0.slot) }
    }

    var body: some View {
        let entries = checkIns
        let days = Array(Set(entries.map(\.day))).sorted(by: >)
        List {
            Section {
                NavigationLink {
                    TeamPageView(path: "pulse-summary", title: "The pulse, summarised")
                } label: {
                    Label("The pulse, summarised", systemImage: "waveform.path.ecg")
                }
            }
            if entries.isEmpty {
                Section {
                    if team.refreshing {
                        ProgressView("Loading the check-ins…")
                    } else {
                        Text("No check-ins yet.").foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(days, id: \.self) { day in
                Section(Lisbon.dayLabel(day)) {
                    ForEach(entries.filter { $0.day == day }) { entry in
                        NavigationLink {
                            PulseEntryView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(entry.who) · \(entry.part)").font(.subheadline.weight(.semibold))
                                Text(Self.preview(entry)).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            Section {
                Link(destination: TeamEndpoints.base.appendingPathComponent("pulse/")) {
                    Label("Open the web page", systemImage: "safari")
                }
            } footer: {
                Text("From web-summit.sgit.ai, public data, kept on this device for offline use.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pulse")
        .refreshable { await team.refresh(person: identity.current?.id) }
        .task { if team.pulse.isEmpty { await team.refresh(person: identity.current?.id) } }
    }

    /// "2026-11-03-morning" → true; "index" → false.
    static func isDated(_ slot: String) -> Bool {
        let day = slot.prefix(10)
        return day.count == 10 && day.enumerated().allSatisfy { index, character in
            index == 4 || index == 7 ? character == "-" : character.isNumber
        }
    }

    /// The first paragraph of the check-in, without its markdown marks.
    static func preview(_ entry: PulseEntry) -> String {
        for block in TeamPageParser.blocks(entry.body) {
            if case .paragraph(let text) = block {
                return String(TeamInline.attributed(text, base: nil).characters)
            }
        }
        return ""
    }
}

/// One check-in in full.
struct PulseEntryView: View {
    let entry: PulseEntry

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(TeamPage(markdown: entry.body).items) { TeamPageBlockView(block: $0.block, base: nil) }
            }
            .padding()
        }
        .navigationTitle("\(entry.who), \(entry.part)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
