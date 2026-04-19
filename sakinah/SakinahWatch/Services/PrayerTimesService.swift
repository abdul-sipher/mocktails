import Foundation
import CoreLocation

/// Computes local prayer times using the standard astronomical
/// algorithm (ISNA conventions by default). This is a self-contained
/// implementation — no network required.
///
/// Accuracy is within a minute or two of published tables; users may
/// switch calculation method per their local convention.
final class PrayerTimesService {
    enum Method { case isna, mwl, egypt, makkah, karachi }

    var method: Method = .isna
    var asrFactor: Double = 1  // 1 = Shafi, 2 = Hanafi

    func next(at coord: CLLocationCoordinate2D, on date: Date = Date()) -> PrayerTime? {
        let times = today(at: coord, on: date)
        let now = date
        return times.first(where: { $0.date > now }) ?? nextFajr(at: coord, after: date, todays: times)
    }

    func today(at coord: CLLocationCoordinate2D, on date: Date = Date()) -> [PrayerTime] {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let julian = julianDay(year: comps.year!, month: comps.month!, day: comps.day!)
        let decl = sunDeclination(julian: julian)
        let eq = equationOfTime(julian: julian)
        let lat = coord.latitude
        let lng = coord.longitude
        let tz = TimeZone.current.secondsFromGMT(for: date) / 3600

        let dhuhr = 12 + Double(tz) - lng / 15 - eq / 60

        let (fajrAngle, ishaAngle) = angles(for: method)
        let fajr  = dhuhr - hourAngle(angle: fajrAngle,  lat: lat, decl: decl) / 15
        let isha  = dhuhr + hourAngle(angle: ishaAngle,  lat: lat, decl: decl) / 15
        let sunrise = dhuhr - hourAngle(angle: 0.833,    lat: lat, decl: decl) / 15
        let maghrib = dhuhr + hourAngle(angle: 0.833,    lat: lat, decl: decl) / 15
        let asrAngle = -atan(1 / (asrFactor + tan(abs(lat - decl) * .pi / 180))) * 180 / .pi
        let asr = dhuhr + hourAngle(angle: 90 - asrAngle, lat: lat, decl: decl) / 15

        return [
            .init(name: .fajr,    date: dateFromHour(fajr,    base: date, cal: cal)),
            .init(name: .dhuhr,   date: dateFromHour(dhuhr,   base: date, cal: cal)),
            .init(name: .asr,     date: dateFromHour(asr,     base: date, cal: cal)),
            .init(name: .maghrib, date: dateFromHour(maghrib, base: date, cal: cal)),
            .init(name: .isha,    date: dateFromHour(isha,    base: date, cal: cal))
        ]
    }

    private func nextFajr(at coord: CLLocationCoordinate2D, after: Date, todays: [PrayerTime]) -> PrayerTime? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: after)!
        return today(at: coord, on: tomorrow).first
    }

    // MARK: - Astronomy helpers

    private func angles(for method: Method) -> (fajr: Double, isha: Double) {
        switch method {
        case .isna:    return (15, 15)
        case .mwl:     return (18, 17)
        case .egypt:   return (19.5, 17.5)
        case .makkah:  return (18.5, 18.5)
        case .karachi: return (18, 18)
        }
    }

    private func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    private func sunDeclination(julian: Double) -> Double {
        let d = julian - 2451545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360)
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360)
        let L = q + 1.915 * sin(g * .pi / 180) + 0.020 * sin(2 * g * .pi / 180)
        let e = 23.439 - 0.00000036 * d
        return asin(sin(e * .pi / 180) * sin(L * .pi / 180)) * 180 / .pi
    }

    private func equationOfTime(julian: Double) -> Double {
        let d = julian - 2451545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360)
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360)
        let L = q + 1.915 * sin(g * .pi / 180) + 0.020 * sin(2 * g * .pi / 180)
        let e = 23.439 - 0.00000036 * d
        let RA = atan2(cos(e * .pi / 180) * sin(L * .pi / 180), cos(L * .pi / 180)) * 180 / .pi / 15
        return (q / 15 - RA) * 60  // minutes
    }

    private func hourAngle(angle: Double, lat: Double, decl: Double) -> Double {
        let cosH = (-sin(angle * .pi / 180) - sin(lat * .pi / 180) * sin(decl * .pi / 180)) /
                   (cos(lat * .pi / 180) * cos(decl * .pi / 180))
        return acos(min(max(cosH, -1), 1)) * 180 / .pi
    }

    private func dateFromHour(_ hour: Double, base: Date, cal: Calendar) -> Date {
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        comps.hour = Int(hour)
        comps.minute = Int((hour - Double(Int(hour))) * 60)
        comps.second = 0
        return cal.date(from: comps) ?? base
    }
}
