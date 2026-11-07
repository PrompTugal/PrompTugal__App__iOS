import SwiftUI

/// "Where is everyone": overlaps, clashes and places to meet, from plans shared through vaults.
/// Entry view for `collab.plans`.
struct TeamPlansView: View {
    var store: CoordinationStore = .shared
    @State private var linking: CoordinationStore.Person?
    @State private var sharing = false

    var body: some View {
        @Bindable var store = store
        let result = store.analysis
        List {
            Section {
                WhatNeedsKeys(store: store)
            }

            Section {
                Picker("Day", selection: $store.day) {
                    ForEach(store.days, id: \.self) { day in
                        let count = result.peoplePerDay[day] ?? 0
                        Text(count > 0 ? "\(Lisbon.dayLabel(day)) · \(count)" : Lisbon.dayLabel(day)).tag(day)
                    }
                }
            } footer: {
                Text("The number after a day is how many of us have picks that day. Lisbon time.")
            }

            Section("Together") {
                if result.together.isEmpty {
                    Text(store.plans.count < 2 ? "Overlaps show once a teammate's plan is linked."
                                               : "No session with two or more of us on this day.")
                        .foregroundStyle(.secondary)
                }
                ForEach(result.together) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(item.event.time) · \(item.event.place)").font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor)
                        Text(item.event.title).font(.headline)
                        Text(item.people.map { store.name($0) }.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            if !result.clashes.isEmpty {
                Section("Clashes") {
                    ForEach(result.clashes) { clash in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(store.name(clash.person), systemImage: "exclamationmark.triangle").font(.subheadline.bold())
                            Text("\(clash.first.time) \(clash.first.title)")
                            Text("\(clash.second.time) \(clash.second.title)")
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section {
                if result.meetSlots.isEmpty {
                    Text("No slot to suggest yet.").foregroundStyle(.secondary)
                }
                ForEach(result.meetSlots) { slot in
                    HStack(alignment: .top) {
                        Image(systemName: slot.kind == .freeWindow ? "clock" : "mappin.and.ellipse")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Lisbon.timeLabel(slot.start))–\(Lisbon.timeLabel(slot.end))").font(.subheadline.monospacedDigit().bold())
                            switch slot.kind {
                            case .afterSession(let event):
                                Text("After “\(event.title)”, at \(slot.place)")
                            case .freeWindow:
                                Text("Nobody has a pick, and no stand-up")
                            }
                            if !slot.people.isEmpty {
                                Text(slot.people.map { store.name($0) }.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Meet here")
            } footer: {
                Text("After a session two or more of us are at, or a free window of 30 minutes or more between 09:00 and 19:00, keeping the 13:00 and 18:00 stand-ups free.")
            }

            Section {
                ForEach(rows(store)) { person in
                    PersonPlanRow(store: store, person: person, picksToday: result.perPerson[person.id]) {
                        linking = person
                    }
                }
            } header: {
                Text("People")
            }

            Section {
                Button {
                    sharing = true
                    Task { await store.shareMyPlan(); sharing = false }
                } label: {
                    Label(sharing ? "Sharing…" : "Share my plan", systemImage: "square.and.arrow.up")
                }
                .disabled(sharing || !(CollabHooks.vault?.canWrite ?? false))
                if let at = store.lastShare {
                    LabeledContent("Last shared", value: at.formatted(date: .omitted, time: .shortened))
                }
            } footer: {
                Text("Writes my picks to \(CoordinationStore.picksPath) in my vault, merged with what the website saved. Teammates who have my vault's read key see them here.")
            }

            if let message = store.message {
                Section { Text(message).font(.footnote) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Where is everyone")
        .refreshable { await store.load() }
        .task { await store.load() }
        .sheet(item: $linking) { person in
            NavigationStack { LinkTeammateView(store: store, person: person) }
                .presentationDetents([.medium])
        }
    }

    private func rows(_ store: CoordinationStore) -> [CoordinationStore.Person] {
        if !store.people.isEmpty { return store.people }
        return store.plans.values.map { .init(id: $0.person, name: $0.name, colour: nil) }
    }
}

private struct WhatNeedsKeys: View {
    let store: CoordinationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What this needs", systemImage: "key.viewfinder").font(.headline)
            row(true, "Team list from the team site (public).")
            row(store.me != nil, store.me.map { "You are \($0.name)." } ?? "Choose who you are in Settings.")
            row(true, "Your picks from this device (\(CollabHooks.myPickIds().count)).")
            row(store.vaultAvailable && store.vaultOpen, store.vaultAvailable
                ? (store.vaultOpen ? "Your vault is open." : "Open your vault to share your plan and read teammates'.")
                : "Vault reading is not in this build yet.")
            row(!store.linkedVaults.isEmpty, "Teammates' plans: \(store.linkedVaults.count) linked. Each needs the read key of their vault, shared once.")
            Text("The team site's public data lists one shortlist for everyone, not personal picks, so it cannot show who goes where.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func row(_ ok: Bool, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ok ? Color.green : Color.secondary)
        }
    }
}

private struct PersonPlanRow: View {
    let store: CoordinationStore
    let person: CoordinationStore.Person
    let picksToday: Int?
    let link: () -> Void

    var body: some View {
        let plan = store.plans[person.id]
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name + (person.id == store.me?.id ? " (me)" : ""))
                Group {
                    if let plan {
                        Text("\(plan.pickIds.count) picks, \(picksToday ?? 0) this day · \(source(plan.source))")
                    } else if let error = store.errors[person.id] {
                        Text(error)
                    } else if store.linkedVaults[person.id] != nil {
                        Text("Linked; open your vault to read")
                    } else {
                        Text("No plan shared with this device")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if person.id != store.me?.id {
                if store.linkedVaults[person.id] != nil {
                    Menu {
                        Button("Unlink", role: .destructive) { store.unlink(person: person.id) }
                    } label: {
                        Image(systemName: "link")
                    }
                } else {
                    Button("Add key", action: link)
                        .buttonStyle(.bordered)
                        .disabled(!store.vaultAvailable)
                }
            }
        }
    }

    private func source(_ source: TeammatePlan.Source) -> String {
        switch source {
        case .me: "this device"
        case .vault(let id): "vault \(id)"
        }
    }
}

private struct LinkTeammateView: View {
    let store: CoordinationStore
    let person: CoordinationStore.Person
    @State private var key = ""
    @State private var working = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                SecureField("sgit_private_read_…:vault id", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Ask \(person.name) for the read key of the vault where their picks are. It can only read, is kept in this device's Keychain behind Face ID, and is never shown again.")
            }
            Section {
                Button(working ? "Linking…" : "Link") {
                    working = true
                    Task {
                        await store.link(person: person.id, readKey: key)
                        key = ""
                        working = false
                        dismiss()
                    }
                }
                .disabled(key.isEmpty || working)
            }
        }
        .navigationTitle("Link \(person.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}
