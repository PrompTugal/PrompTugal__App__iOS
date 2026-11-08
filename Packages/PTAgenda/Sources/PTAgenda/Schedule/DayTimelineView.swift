import SwiftUI
import PTCore
import PTWeb

/// A day drawn as a time line: hours down the side, picks, stand-ups and proposals as blocks, overlapping items
/// side by side, and a "now" line. Used beside the lists on iPad (and in landscape); Lisbon time throughout.
public struct DayTimelineView: View {
    public init(day: String, items: [DayPlanner.Item], startHour: Int = 8, endHour: Int = 22, hourHeight: CGFloat = 64,
                onTap: ((DayPlanner.Item) -> Void)? = nil) {
        self.day = day
        self.items = items
        self.startHour = startHour
        self.endHour = endHour
        self.hourHeight = hourHeight
        self.onTap = onTap
    }

    public let day: String
    public let items: [DayPlanner.Item]
    public var startHour = 8
    public var endHour = 22
    public var hourHeight: CGFloat = 64
    public var onTap: ((DayPlanner.Item) -> Void)?

    public var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    grid
                    blocks
                    nowLine(context.date)
                }
                .frame(height: CGFloat(endHour - startHour) * hourHeight)
                .padding(.vertical, 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Time line for \(Lisbon.dayLabel(day))", bundle: .module))
    }

    private var gutter: CGFloat { 52 }

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 6) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: gutter - 6, alignment: .trailing)
                        .offset(y: -6)
                    Rectangle().fill(.quaternary).frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .accessibilityHidden(true)
    }

    private var blocks: some View {
        GeometryReader { geo in
            let width = geo.size.width - gutter - 4
            ForEach(layout()) { slot in
                let columnWidth = width / CGFloat(slot.columns)
                block(slot.item)
                    .frame(width: max(0, columnWidth - 4), height: max(22, height(slot.item)))
                    .offset(x: gutter + CGFloat(slot.column) * columnWidth, y: y(slot.item.start))
            }
        }
    }

    private func block(_ item: DayPlanner.Item) -> some View {
        let tint: Color = switch item.kind {
        case .pick: .accentColor
        case .standup: .indigo
        case .proposal: .gray
        }
        return Button {
            onTap?(item)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Lisbon.timeLabel(item.start)) \(item.kind == .proposal ? String(localized: "· proposed", bundle: .module) : "")")
                    .font(.caption2.monospacedDigit())
                Text(item.title).font(.caption.weight(.semibold)).lineLimit(2)
                if !item.place.isEmpty { Text(item.place).font(.caption2).lineLimit(1) }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(item.kind == .proposal ? Color.primary : Color.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.kind == .proposal ? tint.opacity(0.15) : tint.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(tint, style: StrokeStyle(lineWidth: 1, dash: item.kind == .proposal ? [4, 3] : []))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(item.title), \(Lisbon.timeLabel(item.start)) to \(Lisbon.timeLabel(item.end))", bundle: .module))
    }

    @ViewBuilder private func nowLine(_ now: Date) -> some View {
        let top = y(now)
        if Lisbon.day(now) == day, top >= 0, top <= CGFloat(endHour - startHour) * hourHeight {
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Rectangle().fill(.red).frame(height: 1.5)
            }
            .padding(.leading, gutter - 4)
            .offset(y: top - 4)
            .accessibilityHidden(true)
        }
    }

    private var dayStart: Date { Lisbon.instant(day: day, clock: String(format: "%02d:00", startHour)) ?? .distantPast }

    private func y(_ date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(dayStart) / 3600) * hourHeight
    }

    private func height(_ item: DayPlanner.Item) -> CGFloat {
        CGFloat(item.end.timeIntervalSince(item.start) / 3600) * hourHeight - 2
    }

    public struct Slot: Identifiable {
        public init(item: DayPlanner.Item, column: Int, columns: Int) {
            self.item = item
            self.column = column
            self.columns = columns
        }

        public var id: String { item.id }
        public let item: DayPlanner.Item
        public var column: Int
        public var columns: Int
    }

    /// Overlapping items share the width, in columns, like a calendar's day view.
    public func layout() -> [Slot] {
        let sorted = items.sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }
        var slots: [Slot] = []
        var group: [Int] = []          // indexes into slots for the current overlapping cluster
        var groupEnd = Date.distantPast
        func closeGroup() {
            let columns = (group.map { slots[$0].column }.max() ?? 0) + 1
            for index in group { slots[index].columns = columns }
            group = []
        }
        for item in sorted {
            if item.start >= groupEnd { closeGroup() }
            var used = Set<Int>()
            for index in group where slots[index].item.end > item.start { used.insert(slots[index].column) }
            var column = 0
            while used.contains(column) { column += 1 }
            slots.append(Slot(item: item, column: column, columns: 1))
            group.append(slots.count - 1)
            groupEnd = max(groupEnd, item.end)
        }
        closeGroup()
        return slots
    }
}
