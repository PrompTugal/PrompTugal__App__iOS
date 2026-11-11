import SwiftUI

/// The four-day strip at the top of each tab.
struct DayStrip: View {
    enum Style { case filled, outlined }
    let days: [Day]
    @Binding var selected: String?
    var style: Style = .filled
    let caption: (Day) -> String
    var marks: (Day) -> [Color] = { _ in [] }
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : max(min(days.count, 4), 1))
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days) { day in
                let isOn = selected == day.key
                Button { selected = day.key } label: {
                    VStack(spacing: 0) {
                        Text(day.shortWeekday).font(.footnote)
                        Text(day.dayNumber).font(.title3.weight(.bold))
                        let dots = marks(day)
                        if dots.isEmpty {
                            Text(caption(day)).font(.footnote).lineLimit(2).multilineTextAlignment(.center)
                        } else {
                            HStack(spacing: 2) {
                                ForEach(Array(dots.enumerated()), id: \.offset) { _, c in
                                    RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 3)
                        }
                    }
                    .foregroundStyle(style == .filled && isOn ? Palette.onAccent : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .padding(.vertical, 4)
                    .background(style == .filled && isOn ? Palette.accent : Palette.panel, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isOn && style == .outlined ? Palette.accent : (style == .filled && isOn ? .clear : Palette.line),
                                      lineWidth: isOn && style == .outlined ? 2 : 1))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day.title). \(caption(day))")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// A section heading in teal, with an optional note on the right.
struct PartHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            if let trailing { Text(trailing) }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(Palette.heading)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "Updated 17:02", or "Offline copy from 17:02" with a retry button.
struct FreshnessLine: View {
    @Environment(FeedStore.self) private var feed

    var body: some View {
        HStack(spacing: 8) {
            Text(feed.freshnessText())
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
            Spacer(minLength: 0)
            if feed.isLoading {
                ProgressView().accessibilityLabel("Checking for updates")
            } else if !feed.isLive {
                Button("Try again") { Task { await feed.refresh() } }
                    .buttonStyle(PillButtonStyle())
                    .font(.footnote)
            }
        }
    }
}

/// Start and end, stacked. "+1" when the event ends after midnight.
struct TimeColumn: View {
    let event: FeedEvent
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 58

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(event.start == nil ? "Time" : event.startText).font(.body.weight(.bold))
            Text(event.start == nil ? "not given" : (event.endText ?? "")).font(.subheadline).foregroundStyle(Palette.ink2)
        }
        .frame(width: width, alignment: .leading)
    }
}

/// One event in the All events list.
struct EventRow: View {
    let event: FeedEvent
    let isSaved: Bool
    let clashes: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        layout {
            TimeColumn(event: event)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.name).font(.headline).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(event.hostName) · \(event.area)").font(.subheadline).foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                FlowPills(event: event, clashes: clashes)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SaveButton(isSaved: isSaved, action: onToggle)
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(event, clashes: clashes, saved: isSaved))
        .accessibilityHint("Opens the details")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onOpen)
        .accessibilityAction(named: isSaved ? "Remove from My events" : "Save to My events", onToggle)
    }

    /// Status first, then time, title, host, place, type.
    static func spoken(_ e: FeedEvent, clashes: Bool, saved: Bool) -> String {
        var parts: [String] = []
        if let word = e.eventStatus.word { parts.append(word) }
        parts.append(e.timeRange.replacingOccurrences(of: "+1", with: "the next day"))
        parts.append(e.name)
        parts.append(e.hostName)
        parts.append(e.area)
        parts.append(e.kindLabel)
        if clashes { parts.append("Same time as one you saved") }
        if saved { parts.append("Saved") }
        return parts.joined(separator: ". ")
    }
}

/// Type, status and clash pills, wrapping onto new lines when needed.
struct FlowPills: View {
    let event: FeedEvent
    let clashes: Bool

    var body: some View {
        WrapLayout(spacing: 4) {
            Pill(text: event.kindLabel)
            if let word = event.eventStatus.word { Pill(text: word, kind: .status) }
            if clashes { Pill(text: "Same time as one you saved", kind: .clash) }
        }
    }
}

struct SaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isSaved ? "Saved" : "Save")
        }
        .buttonStyle(PillButtonStyle(kind: isSaved ? .accent : .plain))
        .accessibilityLabel(isSaved ? "Saved. Remove from My events" : "Save to My events")
    }
}

/// A simple wrapping row for pills.
struct WrapLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
