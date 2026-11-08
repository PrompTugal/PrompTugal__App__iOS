import SwiftUI
import PTCore

/// What picking a session means, as plain rules (spec PICK): which of the person's picks a new one overlaps, and the
/// "Tue 14:00" the toast shows. Pure, so it is tested.
public enum PickRules {
    /// The picks that overlap `event` in time (a session with no end lasts 30 minutes). Touching is not overlapping,
    /// and the event itself never counts. Sorted by start.
    public static func overlapping(_ event: Event, in picks: [SchedulePick]) -> [SchedulePick] {
        guard let start = event.start else { return [] }
        let end = event.end ?? start.addingTimeInterval(NowModel.defaultLength)
        let id = ScheduleID.fromPage(event.page)
        return picks.filter { pick in
            guard pick.id != id, let otherStart = pick.start else { return false }
            let otherEnd = pick.end ?? otherStart.addingTimeInterval(NowModel.defaultLength)
            return otherStart < end && start < otherEnd
        }
        .sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    /// "Tue 14:00": the weekday and the start time in Lisbon time, in the person's language and format.
    public static func whenLabel(_ event: Event) -> String {
        guard let start = event.start else { return event.time }
        let day = start.formatted(Date.FormatStyle(timeZone: Lisbon.zone).weekday(.abbreviated))
        let time = start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Lisbon.zone))
        return "\(day) \(time)"
    }
}

/// Picking a session with feedback: the star fills, a light tap, and a short toast at the bottom ("Added to My
/// program · Tue 14:00", or amber "Added · clashes with …" with a View button). One per app; every star uses it
/// (`PickStarButton`, `AgendaView`, the screens design builds).
@MainActor @Observable
public final class PickFeedback {
    public struct Toast: Identifiable, Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case added(when: String)
            case clash(with: String, pickID: String)       // the title and schedule id of an overlapping pick
        }

        public let id = UUID()
        public let kind: Kind

        public var isClash: Bool {
            if case .clash = kind { return true }
            return false
        }
    }

    public private(set) var toast: Toast?

    @ObservationIgnored private var dismissal: Task<Void, Never>?
    @ObservationIgnored private let visibleFor: Duration

    public init(visibleFor: Duration = .seconds(4)) {
        self.visibleFor = visibleFor
    }

    /// Picks or un-picks `event` in the one schedule, and says so. Un-picking clears the toast: the star shows it.
    public func toggle(_ event: Event, in schedule: ScheduleStore) {
        let wasPicked = schedule.isPicked(event)
        let overlapped = wasPicked ? [] : PickRules.overlapping(event, in: schedule.picks)
        schedule.toggle(event)
        if wasPicked {
            dismiss()
        } else if let first = overlapped.first {
            show(.clash(with: first.title, pickID: first.id))
        } else {
            show(.added(when: PickRules.whenLabel(event)))
        }
    }

    public func dismiss() {
        dismissal?.cancel()
        toast = nil
    }

    private func show(_ kind: Toast.Kind) {
        dismissal?.cancel()
        toast = Toast(kind: kind)
        let id = toast?.id
        dismissal = Task { [weak self, visibleFor] in
            try? await Task.sleep(for: visibleFor)
            guard !Task.isCancelled, let self, self.toast?.id == id else { return }
            self.toast = nil
        }
    }
}

/// The star on a session row: fills red when picked, a light tap, and the toast. Without a `PickFeedback` in the
/// environment it still picks, silently.
public struct PickStarButton: View {
    public init(event: Event) {
        self.event = event
    }

    public let event: Event

    @Environment(ScheduleStore.self) private var schedule
    @Environment(PickFeedback.self) private var feedback: PickFeedback?

    public var body: some View {
        let picked = schedule.isPicked(event)
        Button {
            if let feedback { feedback.toggle(event, in: schedule) } else { schedule.toggle(event) }
        } label: {
            Image(systemName: picked ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(picked ? Palette.red : Palette.muted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .light), trigger: picked)
        .accessibilityLabel(picked ? "Remove from my program" : "Add to my program")
    }
}

extension View {
    /// Shows the pick toast at the bottom of this view and puts the `PickFeedback` every star uses in the
    /// environment. Apply once, at the root of the app's screens.
    public func pickToasts() -> some View { modifier(PickToastHost()) }
}

private struct PickToastHost: ViewModifier {
    @State private var feedback = PickFeedback()
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .environment(feedback)
            .overlay(alignment: .bottom) {
                if let toast = feedback.toast {
                    PickToastView(toast: toast, view: { showProgram(for: toast) })
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.l)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: feedback.toast)
    }

    /// String(localized: "View", bundle: .module) opens My program on the clashing pick: `<scheme>://open/team.schedule?session=<id>`.
    private func showProgram(for toast: PickFeedback.Toast) {
        guard case .clash(_, let pickID) = toast.kind,
              let base = AppLinks.open("team.schedule"),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return }
        parts.queryItems = [URLQueryItem(name: "session", value: pickID)]
        if let url = parts.url { openURL(url) }
        feedback.dismiss()
    }
}

struct PickToastView: View {
    let toast: PickFeedback.Toast
    let view: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: toast.isClash ? "exclamationmark.triangle.fill" : "star.fill")
                .foregroundStyle(toast.isClash ? Palette.amber : Palette.red)
            switch toast.kind {
            case .added(let when):
                Text(String(localized: "Added to My program · \(when)", bundle: .module))
            case .clash(let title, _):
                Text(String(localized: "Added · clashes with \(title)", bundle: .module)).lineLimit(2)
            }
            Spacer(minLength: 0)
            if toast.isClash {
                Button(String(localized: "View", bundle: .module), action: view).font(.subheadline.bold())
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.ink)
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Space.radius).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Space.radius)
            .stroke(toast.isClash ? Palette.amber : Palette.red.opacity(0.4), lineWidth: 1))
        .shadow(radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }
}
