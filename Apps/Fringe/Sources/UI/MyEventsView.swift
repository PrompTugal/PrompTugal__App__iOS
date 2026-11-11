import SwiftUI

/// Tab 2: the events you saved.
struct MyEventsView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(SavedStore.self) private var saved
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var day: String?
    @State private var detail: FeedEvent?

    private var savedEvents: [FeedEvent] { Planner.sorted(saved.saved(in: feed.events)) }
    private var days: [Day] { Planner.days(of: feed.visibleEvents) }
    private var selectedDay: String? {
        day ?? app.day ?? AllEventsView.defaultDay(days, now: Date())
    }
    private var dayEvents: [FeedEvent] { savedEvents.filter { $0.date == selectedDay } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !saved.notices.isEmpty { noticeCard }
                    DayStrip(days: days, selected: $day.withDefault(selectedDay)) { d in
                        let n = savedEvents.filter { $0.date == d.key }.count
                        return n == 0 ? "none" : "\(n) saved"
                    }
                    if let next = Planner.next(of: savedEvents, now: Date()) {
                        NextCard(event: next, onOpen: { detail = next })
                    }
                    FreshnessLine()
                    if let selectedDay {
                        let d = Day(key: selectedDay)
                        PartHeader(title: d.title, trailing: "\(dayEvents.count) \(dayEvents.count == 1 ? "event" : "events")")
                        if dayEvents.isEmpty {
                            Text("Nothing saved for \(d.title) yet. Tap Save on any event to add it here.")
                                .font(.body).foregroundStyle(Palette.ink2)
                        }
                        ForEach(dayEvents) { e in
                            SavedRow(event: e, onRemove: { saved.toggle(e) }, onOpen: { detail = e })
                        }
                        Button("Find more for \(d.longWeekday)") {
                            app.day = selectedDay
                            app.tab = .all
                        }
                        .buttonStyle(PillButtonStyle(fullWidth: true))
                        .padding(.top, 4)
                    }
                    Text("Saved events stay on this phone only.").font(.footnote).foregroundStyle(Palette.ink2).padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                // Pin the content to the screen width, so it never drifts sideways while scrolling.
                .containerRelativeFrame(.horizontal)
            }
            .refreshable { await feed.refresh(); saved.compare(with: feed.events) }
            .background(Palette.bg)
            .navigationTitle("My events")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .sheet(item: $detail) { EventDetailView(event: $0).environment(feed).environment(saved) }
        }
    }

    private var noticeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Changed since you saved", systemImage: "exclamationmark.circle")
                .font(.headline)
            ForEach(saved.notices) { n in
                Text(n.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Button("OK, got it") { saved.dismissNotices() }
                .buttonStyle(PillButtonStyle())
        }
        .foregroundStyle(Palette.statusInk)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.statusBg, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

/// The teal card for the next saved event.
struct NextCard: View {
    let event: FeedEvent
    let onOpen: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next · \(Planner.whenText(event, now: Date()))").font(.subheadline)
            Text(event.name).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text("\(event.timeRange) · \(event.area)").font(.subheadline)
            if let word = event.eventStatus.word { Text(word).font(.subheadline.weight(.bold)) }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                if let maps = event.mapsURL {
                    Button("Open in Maps") { openURL(maps) }.buttonStyle(PillButtonStyle(fullWidth: true))
                }
                if let site = event.websiteURL {
                    Button("Website") { openURL(site) }.buttonStyle(PillButtonStyle(fullWidth: true))
                }
                Button("Details") { onOpen() }.buttonStyle(PillButtonStyle(fullWidth: true))
            }
            .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.nextCard, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

/// A row in My events, with a remove button.
struct SavedRow: View {
    let event: FeedEvent
    let onRemove: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TimeColumn(event: event)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.name).font(.headline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                Text(event.area).font(.subheadline).foregroundStyle(Palette.ink2)
                FlowPills(event: event, clashes: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.body.weight(.semibold))
            }
            .buttonStyle(PillButtonStyle())
            .accessibilityLabel("Remove from My events")
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EventRow.spoken(event, clashes: false, saved: true))
        .accessibilityHint("Opens the details")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onOpen)
        .accessibilityAction(named: "Remove from My events", onRemove)
    }
}
