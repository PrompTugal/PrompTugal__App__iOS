import CoreGraphics
import Foundation

/// Layouts for the abstract Algarve maps. Pure, so they are tested.
public enum AlgarveCartogram {
    // MARK: Tile grid

    /// Each town's cell on a 9 × 3 tile map that keeps the region's shape: the inland towns on the top row, the
    /// western coast down the left, the south coast dipping to Faro, the Guadiana up the right.
    public static let tiles: [String: (col: Int, row: Int)] = [
        "aljezur": (0, 0), "monchique": (2, 0), "silves": (3, 0), "loule": (5, 0), "sao-bras-de-alportel": (6, 0), "alcoutim": (8, 0),
        "vila-do-bispo": (0, 1), "lagos": (1, 1), "portimao": (2, 1), "lagoa": (3, 1), "albufeira": (4, 1), "tavira": (7, 1), "castro-marim": (8, 1),
        "quarteira": (5, 2), "faro": (6, 2), "olhao": (7, 2), "vila-real-de-santo-antonio": (8, 2),
    ]
    public static let columns = 9
    public static let rows = 3

    // MARK: Geography

    /// The region's bounds, and the width of a degree of longitude here relative to latitude (cos 37.2°).
    static let lon: ClosedRange<Double> = -8.98 ... -7.36
    static let lat: ClosedRange<Double> = 36.98 ... 37.52
    static let lonScale = cos(37.2 * Double.pi / 180)

    /// Width over height of the region drawn at true proportions.
    public static var aspect: Double {
        (lon.upperBound - lon.lowerBound) * lonScale / (lat.upperBound - lat.lowerBound)
    }

    /// A town's point in unit coordinates (0...1, y down), at true proportions inside a box of `aspect`.
    public static func unitPoint(latitude: Double, longitude: Double) -> CGPoint {
        CGPoint(x: (longitude - lon.lowerBound) / (lon.upperBound - lon.lowerBound),
                y: 1 - (latitude - lat.lowerBound) / (lat.upperBound - lat.lowerBound))
    }

    // MARK: Dorling cartogram

    public struct Bubble: Equatable, Sendable {
        public let id: String
        public var center: CGPoint
        public let radius: CGFloat
        public let home: CGPoint
    }

    /// Radii with area proportional to `value`, the largest `maxRadius`; a town with nothing still shows, at `minRadius`.
    public static func radii(_ values: [String: Double], maxRadius: CGFloat, minRadius: CGFloat) -> [String: CGFloat] {
        let top = values.values.max() ?? 0
        return values.mapValues { value in
            guard top > 0 else { return minRadius }
            return max(minRadius, maxRadius * CGFloat(sqrt(max(0, value) / top)))
        }
    }

    /// Circles start where their town is and push each other apart until none overlap, each pulled gently home.
    /// Deterministic: same input, same picture.
    public static func dorling(_ input: [Bubble], iterations: Int = 240, padding: CGFloat = 1.5,
                               bounds: CGRect? = nil) -> [Bubble] {
        var bubbles = input.sorted { $0.id < $1.id }
        guard bubbles.count > 1 else { return bubbles }
        for step in 0..<iterations {
            let pull: CGFloat = step < iterations - 40 ? 0.04 : 0
            for i in bubbles.indices {
                bubbles[i].center.x += (bubbles[i].home.x - bubbles[i].center.x) * pull
                bubbles[i].center.y += (bubbles[i].home.y - bubbles[i].center.y) * pull
            }
            for i in 0..<bubbles.count {
                for j in (i + 1)..<bubbles.count {
                    var dx = bubbles[j].center.x - bubbles[i].center.x
                    var dy = bubbles[j].center.y - bubbles[i].center.y
                    var distance = hypot(dx, dy)
                    let need = bubbles[i].radius + bubbles[j].radius + padding
                    guard distance < need else { continue }
                    if distance < 0.001 {
                        // Same spot: split them along a fixed direction so the result does not depend on chance.
                        dx = 1; dy = 0.3; distance = hypot(dx, dy)
                    }
                    let push = (need - distance) / distance
                    let total = bubbles[i].radius + bubbles[j].radius
                    let wi = bubbles[j].radius / total, wj = bubbles[i].radius / total
                    bubbles[i].center.x -= dx * push * wi
                    bubbles[i].center.y -= dy * push * wi
                    bubbles[j].center.x += dx * push * wj
                    bubbles[j].center.y += dy * push * wj
                }
            }
            if let bounds {
                for i in bubbles.indices {
                    let r = bubbles[i].radius
                    bubbles[i].center.x = min(max(bubbles[i].center.x, bounds.minX + r), bounds.maxX - r)
                    bubbles[i].center.y = min(max(bubbles[i].center.y, bounds.minY + r), bounds.maxY - r)
                }
            }
        }
        return bubbles
    }

    /// The largest overlap left between any two circles (0 when none overlap).
    public static func worstOverlap(_ bubbles: [Bubble]) -> CGFloat {
        var worst: CGFloat = 0
        for i in 0..<bubbles.count {
            for j in (i + 1)..<bubbles.count {
                let d = hypot(bubbles[j].center.x - bubbles[i].center.x, bubbles[j].center.y - bubbles[i].center.y)
                worst = max(worst, bubbles[i].radius + bubbles[j].radius - d)
            }
        }
        return worst
    }

    // MARK: Colour

    /// 0...1 on a square-root scale, so one big town does not wash out the rest.
    public static func intensity(_ value: Double, max top: Double) -> Double {
        guard top > 0 else { return 0 }
        return sqrt(min(max(value, 0), top) / top)
    }
}
