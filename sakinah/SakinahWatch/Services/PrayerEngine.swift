import Foundation
import CoreLocation
import Adhan

/// Prayer times from the Adhan library for a place, day and settings.
/// Pure: no location services, no clock reads beyond its arguments.
enum PrayerEngine {
    static func parameters(for settings: PrayerSettings) -> CalculationParameters {
        var params = settings.method.params
        params.madhab = settings.asr.adhan
        params.highLatitudeRule = settings.highLatitude.adhan
        // User offsets; Adhan keeps its own per-method adjustments separately.
        params.adjustments = PrayerAdjustments(
            fajr: settings.offset(for: .fajr),
            dhuhr: settings.offset(for: .dhuhr),
            asr: settings.offset(for: .asr),
            maghrib: settings.offset(for: .maghrib),
            isha: settings.offset(for: .isha)
        )
        return params
    }

    /// Times for the calendar day containing `day` in `timeZone`.
    /// nil when Adhan cannot compute them (extreme latitude).
    static func timetable(on day: Date,
                          at coordinate: CLLocationCoordinate2D,
                          timeZone: TimeZone,
                          settings: PrayerSettings) -> DayTimetable? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: day) else { return nil }
        let coords = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let params = parameters(for: settings)

        guard
            let today = PrayerTimes(coordinates: coords,
                                    date: cal.dateComponents([.year, .month, .day], from: day),
                                    calculationParameters: params),
            let next = PrayerTimes(coordinates: coords,
                                   date: cal.dateComponents([.year, .month, .day], from: tomorrow),
                                   calculationParameters: params),
            let sunnah = SunnahTimes(from: today)
        else { return nil }

        return DayTimetable(
            fajr: today.fajr,
            sunrise: today.sunrise,
            dhuhr: today.dhuhr,
            asr: today.asr,
            maghrib: today.maghrib,
            isha: today.isha,
            nextFajr: next.fajr,
            middleOfNight: sunnah.middleOfTheNight,
            lastThirdOfNight: sunnah.lastThirdOfTheNight,
            isFriday: cal.component(.weekday, from: day) == 6
        )
    }

    /// Current window, including last night's Isha before today's Fajr.
    static func currentWindow(at now: Date,
                              at coordinate: CLLocationCoordinate2D,
                              timeZone: TimeZone,
                              settings: PrayerSettings) -> PrayerWindow? {
        if let w = timetable(on: now, at: coordinate, timeZone: timeZone, settings: settings)?.window(at: now) {
            return w
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return nil }
        return timetable(on: yesterday, at: coordinate, timeZone: timeZone, settings: settings)?.window(at: now)
    }
}
