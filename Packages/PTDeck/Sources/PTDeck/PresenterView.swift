import PTCore
import SwiftUI

/// Presenter mode for iPad. The slide goes full screen on the external display or AirPlay; the iPad shows
/// the current slide, the next slide, the speaker notes and a timer.
public struct PresenterView: View {
    let deck: Deck
    let store: DeckStore
    let onClose: () -> Void
    @State private var index: Int
    @State private var timer = PresenterTimer()
    private let output = PresenterOutput.shared

    public init(deck: Deck, start: Int = 0, store: DeckStore, onClose: @escaping () -> Void) {
        self.deck = deck
        self.store = store
        self.onClose = onClose
        _index = State(initialValue: min(max(0, start), max(0, deck.slides.count - 1)))
    }

    private var current: DeckSlide { deck.slides[index] }
    private var next: DeckSlide? { index + 1 < deck.slides.count ? deck.slides[index + 1] : nil }
    private func position(_ i: Int) -> String { "\(i + 1) / \(deck.slides.count)" }

    public var body: some View {
        VStack(spacing: Space.l) {
            header
            HStack(alignment: .top, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Now").font(Typo.kicker).foregroundStyle(Palette.muted)
                    SlideCanvas(slide: current, deckTitle: deck.title, position: position(index), store: store)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.rule))
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Next").font(Typo.kicker).foregroundStyle(Palette.muted)
                        if let next {
                            SlideCanvas(slide: next, deckTitle: deck.title, position: position(index + 1), store: store)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.rule))
                        } else {
                            Text("End of deck").font(Typo.headline).foregroundStyle(Palette.muted)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Palette.paper2)
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Notes").font(Typo.kicker).foregroundStyle(Palette.muted)
                        ScrollView {
                            Text(current.notes?.isEmpty == false ? current.notes! : "No speaker notes for this slide.")
                                .font(.title3)
                                .foregroundStyle(current.notes?.isEmpty == false ? Palette.ink : Palette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            controls
        }
        .padding(Space.l)
        .background(Palette.paper.ignoresSafeArea())
        .onAppear { publish(); timer.start() }
        .onChange(of: index) { publish() }
        .onDisappear { output.frame = nil; output.store = nil }
        .gesture(DragGesture(minimumDistance: 40).onEnded { value in
            if value.translation.width < 0 { go(1) } else { go(-1) }
        })
    }

    private var header: some View {
        HStack {
            Button("End", systemImage: "xmark.circle", action: onClose)
            Spacer()
            Label(output.isConnected ? "External display connected" : "No external display: mirroring",
                  systemImage: output.isConnected ? "tv" : "airplayvideo")
                .font(Typo.meta).foregroundStyle(Palette.muted)
            Spacer()
            TimerLabel(timer: timer)
        }
    }

    private var controls: some View {
        HStack(spacing: Space.xl) {
            Button("Previous", systemImage: "chevron.left") { go(-1) }.disabled(index == 0)
            Text(position(index)).font(Typo.number)
            Button("Next", systemImage: "chevron.right") { go(1) }.disabled(next == nil)
            Spacer()
            Button(timer.isRunning ? "Pause" : "Start", systemImage: timer.isRunning ? "pause" : "play") { timer.toggle() }
            Button("Reset", systemImage: "arrow.counterclockwise") { timer.reset() }
        }
        .buttonStyle(.bordered)
        .labelStyle(.titleAndIcon)
    }

    private func go(_ step: Int) {
        index = min(max(0, index + step), deck.slides.count - 1)
    }

    private func publish() {
        output.store = store
        output.frame = .init(slide: current, deckTitle: deck.title, position: position(index))
    }
}

/// An elapsed-time counter that can pause. Pure state, so it is tested without a clock.
@MainActor @Observable
public final class PresenterTimer {
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public func start(now: Date = Date()) {
        if startedAt == nil { startedAt = now }
    }

    public func pause(now: Date = Date()) {
        if let startedAt { accumulated += now.timeIntervalSince(startedAt) }
        startedAt = nil
    }

    public func toggle(now: Date = Date()) {
        isRunning ? pause(now: now) : start(now: now)
    }

    public func reset(now: Date = Date()) {
        accumulated = 0
        startedAt = isRunning ? now : nil
    }

    public func elapsed(now: Date = Date()) -> TimeInterval {
        accumulated + (startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    public static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

struct TimerLabel: View {
    let timer: PresenterTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(PresenterTimer.format(timer.elapsed(now: context.date)))
                .font(Typo.number)
                .foregroundStyle(Palette.ink)
                .accessibilityLabel("Elapsed \(PresenterTimer.format(timer.elapsed(now: context.date)))")
        }
    }
}
