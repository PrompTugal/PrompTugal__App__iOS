import SwiftUI

/// The event, as a sheet over the list.
struct EventDetailView: View {
    let event: FeedEvent
    @Environment(FeedStore.self) private var feed
    @Environment(SavedStore.self) private var saved
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showAddress = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    if let word = event.eventStatus.word {
                        Pill(text: word, kind: .status).font(.subheadline)
                            .accessibilityLabel("Status: \(word)")
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)) }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityLabel("Close")
                }
                Text(event.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(summaryLine).font(.subheadline).foregroundStyle(Palette.ink2)

                whenCard
                whereCard
                hostCard

                if let site = event.websiteURL {
                    Button("Event website") { openURL(site) }
                        .buttonStyle(PillButtonStyle(fullWidth: true))
                }
                Button {
                    saved.toggle(event)
                } label: {
                    Label(saved.isSaved(event) ? "Saved. Remove from My events" : "Add to My events",
                          systemImage: saved.isSaved(event) ? "checkmark" : "plus")
                }
                .buttonStyle(PillButtonStyle(kind: saved.isSaved(event) ? .plain : .accent, fullWidth: true))

                Text(footer).font(.footnote).foregroundStyle(Palette.ink2).padding(.top, 4)
            }
            .padding(16)
        }
        .background(Palette.bg)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddress) { AddressView(text: event.fullAddress, name: event.name) }
    }

    /// "Side event · AI agents · Free · Register on the event website"
    private var summaryLine: String {
        var parts = [event.kindLabel]
        if let topic = event.topics.first { parts.append(FeedEvent.capitalisedFirst(topic)) }
        if let cost = event.costLabel { parts.append(cost) }
        if let join = event.joinLine { parts.append(join) }
        return parts.joined(separator: " · ")
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("When").font(.subheadline).foregroundStyle(Palette.ink2)
            Text(event.start == nil ? "\(Day(key: event.date).longTitle), time not given"
                 : "\(Day(key: event.date).longTitle), \(event.timeRange)")
                .font(.headline).foregroundStyle(Palette.ink)
            if event.eventStatus != .on, event.eventStatus != .online, let note = event.stormNote, !note.isEmpty {
                Text(note).font(.subheadline).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var whereCard: some View {
        let lines = event.addressLines
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Where").font(.subheadline).foregroundStyle(Palette.ink2)
                Text(lines.first).font(.headline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                if let second = lines.second {
                    Text(second).font(.subheadline).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                }
                if event.isPrivateAddress {
                    Text("The host gives the address to guests.").font(.subheadline).foregroundStyle(Palette.ink2)
                }
            }
            .accessibilityElement(children: .combine)
            if !event.isOnline {
                WrapLayout(spacing: 6) {
                    if let maps = event.mapsURL {
                        Button { openURL(maps) } label: { Label("Open in Maps", systemImage: "mappin.and.ellipse") }
                            .buttonStyle(PillButtonStyle(kind: .teal))
                    }
                    if !event.isPrivateAddress {
                        Button("Show address") { showAddress = true }
                            .buttonStyle(PillButtonStyle())
                            .accessibilityHint("Shows the address in large text, to show a driver")
                    }
                }
            }
        }
        .card()
    }

    private var hostCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Host").font(.subheadline).foregroundStyle(Palette.ink2)
            Text(event.hostName).font(.headline).foregroundStyle(Palette.ink)
            if let line = feed.hostLines[event.id] {
                Text(line).font(.subheadline).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var footer: String {
        var text = ""
        if let read = event.readAt {
            let today = FeedDate.dayString(read) == FeedDate.dayString(Date())
            text = today ? "Checked today at \(FeedDate.hhmm(read)). "
                : "Checked on \(Day(key: FeedDate.dayString(read)).shortTitle) at \(FeedDate.hhmm(read)). "
        }
        return text + "Independent of Web Summit."
    }
}

/// The address in large text. Works offline.
struct AddressView: View {
    let text: String
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(PillButtonStyle())
            }
            Text(name).font(.headline).foregroundStyle(Palette.ink2)
            Text(text)
                .font(.system(size: 40, weight: .bold))
                .minimumScaleFactor(0.4)
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
    }
}
