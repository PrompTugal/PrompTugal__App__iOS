import SwiftUI

/// Tab 3: the week strip, then the chosen day as a timeline of saved events.
struct CalendarView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(SavedStore.self) private var saved
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var day: String?
    @State private var week = false
    @State private var detail: FeedEvent?

    private var savedEvents: [FeedEvent] { Planner.sorted(saved.saved(in: feed.events)) }
    private var days: [Day] { Planner.days(of: feed.visibleEvents) }
    private var selectedDay: String? { day ?? app.day ?? AllEventsView.defaultDay(days, now: Date()) }

    private func events(on key: String) -> [FeedEvent] { savedEvents.filter { $0.date == key } }

    private func colour(_ e: FeedEvent) -> Color {
        Palette.calendar[Planner.colourIndex(of: e, in: events(on: e.date))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DayStrip(days: days, selected: $day.withDefault(selectedDay), style: .outlined,
                             caption: { d in
                                 let n = events(on: d.key).count
                                 return n == 0 ? "none" : "\(n) saved"
                             },
                             marks: { d in events(on: d.key).map(colour) })
                    HStack(spacing: 6) {
                        Button("Day") { week = false }
                            .buttonStyle(PillButtonStyle(kind: week ? .plain : .accent))
                            .accessibilityAddTraits(week ? [] : .isSelected)
                        Button("Week") { week = true }
                            .buttonStyle(PillButtonStyle(kind: week ? .accent : .plain))
                            .accessibilityAddTraits(week ? .isSelected : [])
                    }
                    if week {
                        ForEach(days) { d in
                            Text(Planner.daySummary(day: d, saved: events(on: d.key)))
                                .font(.subheadline).foregroundStyle(Palette.ink2)
                                .padding(.top, 6)
                            dayList(events(on: d.key))
                        }
                    } else if let selectedDay {
                        let list = events(on: selectedDay)
                        Text(Planner.daySummary(day: Day(key: selectedDay), saved: list))
                            .font(.subheadline).foregroundStyle(Palette.ink2)
                        if list.isEmpty {
                            Button("Find events for \(Day(key: selectedDay).longWeekday)") {
                                app.day = selectedDay
                                app.tab = .all
                            }
                            .buttonStyle(PillButtonStyle(fullWidth: true))
                        } else if typeSize.isAccessibilitySize {
                            dayList(list)
                        } else {
                            Timeline(events: list, colour: colour, onOpen: { detail = $0 })
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.bg)
            .navigationTitle("Calendar")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .sheet(item: $detail) { EventDetailView(event: $0).environment(feed).environment(saved) }
        }
    }

    /// The list form: used for the week and at accessibility text sizes.
    private func dayList(_ list: [FeedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(list) { e in
                Button { detail = e } label: {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).fill(colour(e)).frame(width: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.timeRange).font(.subheadline.weight(.bold))
                            Text(e.name).font(.headline).multilineTextAlignment(.leading)
                            Text([e.kindLabel, e.eventStatus.word].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(Palette.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Palette.ink)
                    .card()
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(EventRow.spoken(e, clashes: false, saved: true))
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

/// Hour lines and coloured blocks. Overlapping events sit side by side.
struct Timeline: View {
    let events: [FeedEvent]
    let colour: (FeedEvent) -> Color
    let onOpen: (FeedEvent) -> Void
    @ScaledMetric(relativeTo: .body) private var hourHeight: CGFloat = 75
    @ScaledMetric(relativeTo: .caption) private var gutter: CGFloat = 46

    private var range: (start: Int, end: Int) {
        let starts = events.compactMap(\.startMinute)
        let ends = events.compactMap { $0.endMinute ?? $0.startMinute.map { $0 + 60 } }
        let first = (starts.min() ?? 9 * 60) / 60
        let last = min(((ends.max() ?? 18 * 60) + 59) / 60, 30)
        return (first, max(last, first + 1))
    }

    var body: some View {
        let r = range
        let placements = Planner.placements(events)
        let height = CGFloat(r.end - r.start) * hourHeight
        GeometryReader { geo in
            let width = geo.size.width - gutter
            ZStack(alignment: .topLeading) {
                ForEach(r.start...r.end, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 4) {
                        Text(String(format: "%02d:00", hour % 24)).font(.caption).foregroundStyle(Palette.ink2)
                        Rectangle().fill(Palette.line).frame(height: 1)
                    }
                    .offset(y: CGFloat(hour - r.start) * hourHeight)
                    .accessibilityHidden(true)
                }
                ForEach(events) { e in
                    if let s = e.startMinute {
                        let endM = min(e.endMinute ?? s + 60, r.end * 60)
                        let p = placements[e.id] ?? Planner.Placement(column: 0, columns: 1)
                        let colW = width / CGFloat(p.columns)
                        let top = CGFloat(s - r.start * 60) / 60 * hourHeight
                        let h = max(CGFloat(endM - s) / 60 * hourHeight - 2, 44)
                        Button { onOpen(e) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.kindLabel).font(.footnote.weight(.bold))
                                Text(e.name).font(.footnote).lineLimit(2)
                                Text(e.timeRange).font(.footnote)
                                if let word = e.eventStatus.word { Text(word).font(.footnote.weight(.bold)) }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(width: colW - 4, height: h, alignment: .topLeading)
                            .background(colour(e), in: RoundedRectangle(cornerRadius: 12))
                            .clipped()
                        }
                        .buttonStyle(.plain)
                        .offset(x: gutter + CGFloat(p.column) * colW, y: top + 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(EventRow.spoken(e, clashes: false, saved: true))
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
        .frame(height: height + 20)
    }
}
