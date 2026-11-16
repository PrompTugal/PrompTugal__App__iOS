import PTCore
import SwiftUI

/// "Replay the last 24 hours": a bar per hour (how many agents fired in it, from the dashboard's grid), a scrubber, and
/// play. While replaying, the board lights each agent in the hours it fired. Under Reduce Motion there is no autoplay;
/// the scrubber still works.
struct ReplayControl: View {
    let extras: LiveDashboardExtras
    @Binding var position: Double?
    @State private var playing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hours: Int { extras.gridHours.count }

    var body: some View {
        let counts = LiveReplay.perHour(extras)
        let top = max(1, counts.max() ?? 1)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(position == nil ? "Replay the last 24 hours" : label(counts))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Spacer()
                if position != nil {
                    Button("Back to live") { stop(); position = nil }.font(.footnote)
                }
                if !reduceMotion {
                    Button { playing ? stop() : play() } label: {
                        Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill").font(.title2)
                    }
                    .accessibilityLabel(playing ? "Pause the replay" : "Play the last 24 hours")
                }
            }
            Canvas { context, size in
                let gap: CGFloat = 2
                let w = (size.width - gap * CGFloat(hours - 1)) / CGFloat(hours)
                for (i, count) in counts.enumerated() {
                    let h: CGFloat = max(2, size.height * CGFloat(count) / CGFloat(top))
                    let rect = CGRect(x: CGFloat(i) * (w + gap), y: size.height - h, width: w, height: h)
                    let current = position.map { Int($0) == i } ?? false
                    context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                 with: .color(current ? Palette.sun : Palette.blue.opacity(0.55)))
                }
            }
            .frame(height: 36)
            .accessibilityHidden(true)
            Slider(value: scrub, in: 0...upper)
                .accessibilityLabel("Hour of the replay")
                .accessibilityValue(spokenHour)
            HStack {
                Text((extras.gridHours.first ?? "") + ":00")
                Spacer()
                Text("UTC, from the dashboard's grid of where each agent fired")
                Spacer()
                Text((extras.gridHours.last ?? "") + ":00")
            }
            .font(.caption2).foregroundStyle(Palette.muted)
        }
        .padding(Space.m)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .task(id: playing) {
            guard playing else { return }
            var at = (position ?? 0) >= Double(hours) - 0.05 ? 0 : (position ?? 0)
            while playing, !Task.isCancelled {
                at += 0.06
                if at >= Double(hours) { playing = false; break }
                position = at
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private var upper: Double { Double(hours) - 0.01 }

    private var scrub: Binding<Double> {
        Binding(get: { position ?? upper },
                set: { value in
                    stop()
                    position = min(max(0, value), upper)
                })
    }

    private var spokenHour: String {
        guard let position else { return "Live" }
        let i = min(hours - 1, max(0, Int(position)))
        return extras.gridHours[i] + ":00 UTC"
    }

    private func label(_ counts: [Int]) -> String {
        guard let position else { return "" }
        let i = min(hours - 1, max(0, Int(position)))
        let n = counts.indices.contains(i) ? counts[i] : 0
        return "\(extras.gridHours[i]):00 UTC · \(n) agent\(n == 1 ? "" : "s") fired"
    }

    private func play() { if position == nil { position = 0 }; playing = true }
    private func stop() { playing = false }
}
