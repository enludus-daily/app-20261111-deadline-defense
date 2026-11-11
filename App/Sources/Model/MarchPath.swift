import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// 地図の上の道。入口（左上）から城（下のまんなか）まで曲がりくねる。
/// 位置は 0〜1 の割合で受け取り、道の長さに沿って均等に置く。
struct MarchPath: Sendable {
    /// 道の通り道（地図の幅・高さに対する割合）
    static let waypoints: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.05),
        CGPoint(x: 0.55, y: 0.09),
        CGPoint(x: 0.86, y: 0.22),
        CGPoint(x: 0.52, y: 0.36),
        CGPoint(x: 0.16, y: 0.50),
        CGPoint(x: 0.40, y: 0.64),
        CGPoint(x: 0.82, y: 0.70),
        CGPoint(x: 0.66, y: 0.82),
        CGPoint(x: 0.50, y: 0.87),
    ]

    /// 砲台を置く場所（割合）。レベルが上がると前から順に増える
    static let towerSpots: [CGPoint] = [
        CGPoint(x: 0.30, y: 0.80),
        CGPoint(x: 0.80, y: 0.47),
        CGPoint(x: 0.28, y: 0.28),
        CGPoint(x: 0.66, y: 0.54),
        CGPoint(x: 0.88, y: 0.86),
        CGPoint(x: 0.12, y: 0.70),
    ]

    /// 城の場所（割合）
    static let castleSpot = CGPoint(x: 0.50, y: 0.93)

    let size: CGSize
    let points: [CGPoint]
    private let lengths: [CGFloat]

    init(size: CGSize, samples: Int = 160) {
        self.size = size
        let scaled = Self.waypoints.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        var pts: [CGPoint] = []
        let segments = scaled.count - 1
        let perSegment = max(4, samples / max(1, segments))
        for i in 0..<segments {
            let p0 = scaled[max(i - 1, 0)]
            let p1 = scaled[i]
            let p2 = scaled[i + 1]
            let p3 = scaled[min(i + 2, scaled.count - 1)]
            for step in 0..<perSegment {
                let t = CGFloat(step) / CGFloat(perSegment)
                pts.append(Self.catmullRom(p0, p1, p2, p3, t))
            }
        }
        pts.append(scaled[scaled.count - 1])
        points = pts
        var acc: [CGFloat] = [0]
        for i in 1..<pts.count {
            acc.append(acc[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))
        }
        lengths = acc
    }

    var totalLength: CGFloat { lengths.last ?? 0 }

    /// 道の上の点（progress 0 = 入口、1 = 城の前）
    func point(at progress: Double) -> CGPoint {
        locate(progress).point
    }

    /// 道の向きに直角な向き（列をずらすのに使う）
    func normal(at progress: Double) -> CGVector {
        let tangent = locate(progress).tangent
        return CGVector(dx: -tangent.dy, dy: tangent.dx)
    }

    func point(at progress: Double, lane: Int, spacing: CGFloat) -> CGPoint {
        let base = point(at: progress)
        let n = normal(at: progress)
        let offset = CGFloat(lane - 1) * spacing
        return CGPoint(x: base.x + n.dx * offset, y: base.y + n.dy * offset)
    }

    private func locate(_ progress: Double) -> (point: CGPoint, tangent: CGVector) {
        guard points.count > 1, totalLength > 0 else { return (points.first ?? .zero, CGVector(dx: 1, dy: 0)) }
        let target = CGFloat(min(max(progress, 0), 1)) * totalLength
        var low = 0, high = lengths.count - 1
        while low < high - 1 {
            let mid = (low + high) / 2
            if lengths[mid] < target { low = mid } else { high = mid }
        }
        let a = points[low], b = points[high]
        let span = lengths[high] - lengths[low]
        let t = span > 0 ? (target - lengths[low]) / span : 0
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.0001)
        return (CGPoint(x: a.x + dx * t, y: a.y + dy * t), CGVector(dx: dx / len, dy: dy / len))
    }

    static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let t2 = t * t, t3 = t2 * t
        func f(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        }
        return CGPoint(x: f(p0.x, p1.x, p2.x, p3.x), y: f(p0.y, p1.y, p2.y, p3.y))
    }
}
