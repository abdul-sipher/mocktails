import Foundation

/// The user's own average wrist orientation in each posture, recorded
/// once with consent. Only these averages are kept, never the raw stream.
struct CalibrationProfile: Codable, Equatable {
    struct Point: Codable, Equatable {
        var gx: Double
        var gy: Double
        var gz: Double

        func distance(to o: Point) -> Double {
            ((gx - o.gx) * (gx - o.gx) + (gy - o.gy) * (gy - o.gy) + (gz - o.gz) * (gz - o.gz)).squareRoot()
        }

        static func mean(_ points: [Point]) -> Point? {
            guard !points.isEmpty else { return nil }
            let n = Double(points.count)
            return Point(gx: points.map(\.gx).reduce(0, +) / n,
                         gy: points.map(\.gy).reduce(0, +) / n,
                         gz: points.map(\.gz).reduce(0, +) / n)
        }
    }

    /// Postures recorded during calibration, in order.
    static let postures: [Posture] = [.qiyam, .ruku, .sujood, .jalsa]
    static let key = "calibration.v1"
    /// Beyond this gravity distance from every recorded posture: unsure.
    static let maxDistance = 0.45

    var points: [Posture: Point]
    var recordedAt: Date

    /// Nearest recorded posture and a 0…1 confidence; nil when the
    /// sample is far from all of them.
    func classify(_ p: Point) -> (posture: Posture, confidence: Double)? {
        let ranked = points.map { ($0.key, $0.value.distance(to: p)) }.sorted { $0.1 < $1.1 }
        guard let best = ranked.first, best.1 <= Self.maxDistance else { return nil }
        // Confident when clearly nearer one posture than the runner-up.
        let runnerUp = ranked.dropFirst().first?.1 ?? Self.maxDistance * 2
        let margin = min(1, max(0, (runnerUp - best.1) / Self.maxDistance))
        return (best.0, margin)
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> CalibrationProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CalibrationProfile.self, from: data)
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    static func delete(from defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: key)
    }
}
