import Foundation
import CoreLocation

/// Pure qibla geometry, kept separate so it can be unit tested.
enum QiblaMath {
    /// The Kaʿbah.
    static let kaaba = CLLocationCoordinate2D(latitude: 21.422487, longitude: 39.826206)
    /// Within this many degrees counts as facing the qibla.
    static let alignedTolerance = 5.0

    enum Turn: Equatable {
        case aligned
        case left(Double)
        case right(Double)
    }

    /// Shortest turn from `heading` to `qibla` (both degrees from the same north).
    static func turn(qibla: Double, heading: Double) -> Turn {
        var delta = (qibla - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        if abs(delta) <= alignedTolerance { return .aligned }
        return delta > 0 ? .right(delta) : .left(-delta)
    }

    static func distanceToMakkah(from c: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: c.latitude, longitude: c.longitude)
            .distance(from: CLLocation(latitude: kaaba.latitude, longitude: kaaba.longitude))
    }

    static func cardinal(_ degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let i = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        return names[i]
    }
}

/// "Can I make it?" — travel time against the prayer start. Uses only
/// real ETAs; with no ETA it says nothing rather than guess.
enum ArrivalAdvice {
    struct Advice: Equatable {
        let headline: String
        let canMakeStart: Bool
    }

    static func advise(prayer: PrayerName, prayerStart: Date, windowEnd: Date?,
                       travel: TimeInterval?, mode: String, now: Date) -> Advice? {
        guard let travel else { return nil }
        let minutesToStart = Int((prayerStart.timeIntervalSince(now) / 60).rounded(.down))
        let travelMinutes = max(1, Int((travel / 60).rounded(.up)))
        if prayerStart > now {
            let fits = now.addingTimeInterval(travel) <= prayerStart
            return Advice(
                headline: "\(prayer.title) begins in \(minutesToStart) min. \(mode) takes \(travelMinutes) min — "
                    + (fits ? "you can make it." : "you'd arrive after it begins."),
                canMakeStart: fits)
        }
        if let windowEnd, now.addingTimeInterval(travel) < windowEnd {
            return Advice(headline: "\(prayer.title) time is in. \(mode) takes \(travelMinutes) min; the time lasts until \(windowEnd.formatted(date: .omitted, time: .shortened)).",
                          canMakeStart: false)
        }
        return nil
    }
}
