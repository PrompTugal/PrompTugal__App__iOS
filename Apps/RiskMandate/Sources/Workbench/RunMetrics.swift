import Foundation

/// Timing of one streamed run: time to first token, tokens per second and total time.
/// Pure value code, so it is tested on CI where no on-device model runs.
struct RunMetrics: Equatable, Sendable {
    /// Seconds from sending the prompt to the first streamed text.
    var timeToFirstToken: TimeInterval?
    /// Seconds from sending the prompt to the end of the stream.
    var total: TimeInterval
    /// Tokens in the answer.
    var tokens: Int
    /// True when `tokens` is estimated from the text rather than counted by the model.
    var tokensAreEstimated: Bool

    /// Generation speed: tokens after the first one, over the time after the first one.
    /// Falls back to tokens over total time when the stream had a single chunk.
    var tokensPerSecond: Double? {
        guard tokens > 0, total > 0 else { return nil }
        if let ttft = timeToFirstToken, tokens > 1, total - ttft > 0 {
            return Double(tokens - 1) / (total - ttft)
        }
        return Double(tokens) / total
    }
}

enum TokenEstimate {
    /// About four characters per token for English text, the usual rule of thumb.
    /// Used where the model gives no exact count; the screen labels it "≈".
    static func tokens(in text: String) -> Int {
        let count = text.count
        guard count > 0 else { return 0 }
        return max(1, Int((Double(count) / 4.0).rounded()))
    }
}

/// Records the moments of a streamed run with a monotonic clock.
struct RunClock: Sendable {
    private let start: ContinuousClock.Instant
    private var first: ContinuousClock.Instant?

    init(start: ContinuousClock.Instant = .now) { self.start = start }

    /// Call on every chunk; only the first one is kept.
    mutating func markChunk(at instant: ContinuousClock.Instant = .now) {
        if first == nil { first = instant }
    }

    func finish(text: String, at end: ContinuousClock.Instant = .now) -> RunMetrics {
        RunMetrics(
            timeToFirstToken: first.map { Self.seconds(start, $0) },
            total: Self.seconds(start, end),
            tokens: TokenEstimate.tokens(in: text),
            tokensAreEstimated: true
        )
    }

    private static func seconds(_ a: ContinuousClock.Instant, _ b: ContinuousClock.Instant) -> TimeInterval {
        let d = a.duration(to: b).components
        return TimeInterval(d.seconds) + TimeInterval(d.attoseconds) / 1e18
    }
}
