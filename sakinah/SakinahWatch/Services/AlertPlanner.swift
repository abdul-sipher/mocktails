import Foundation

/// A local notification to schedule. Ids are stable for the same prayer
/// so rescheduling replaces rather than duplicates.
struct PlannedAlert: Equatable {
    let id: String
    let date: Date
    let title: String
    let body: String
}

/// Decides which prayer alerts to schedule. Pure, so it is unit tested;
/// `NotificationScheduler` hands the result to the system.
enum AlertPlanner {
    /// watchOS keeps at most 64 pending notifications per app.
    static let limit = 60
    static let headsUpChoices = [0, 5, 10, 15, 20]

    static func plan(timetables: [DayTimetable],
                     settings: PrayerSettings,
                     now: Date,
                     mosque: (name: String, distanceMeters: Double)?,
                     hasWudu: Bool = false) -> [PlannedAlert] {
        guard settings.prayerAlerts else { return [] }
        var alerts: [PlannedAlert] = []

        for day in timetables {
            for prayer in day.prayers {
                let name = prayer.name.displayTitle(isFriday: day.isFriday)
                let stamp = Int(prayer.date.timeIntervalSince1970)

                if prayer.date > now {
                    alerts.append(PlannedAlert(
                        id: "prayer-\(stamp)-\(prayer.name.rawValue)",
                        date: prayer.date,
                        title: name,
                        body: "It is time for \(name)."
                    ))
                }

                let lead = settings.headsUpMinutes
                let headsUp = prayer.date.addingTimeInterval(TimeInterval(-lead * 60))
                if lead > 0, headsUp > now {
                    var body: String
                    if settings.mosqueNudge, let mosque {
                        body = "Pray at \(mosque.name) (\(Int(mosque.distanceMeters)) m)?"
                    } else {
                        body = "Time to prepare for prayer."
                    }
                    if settings.wuduReminder && !hasWudu {
                        body += " Make wudu before you leave."
                    }
                    alerts.append(PlannedAlert(
                        id: "headsup-\(stamp)-\(prayer.name.rawValue)",
                        date: headsUp,
                        title: "\(name) in \(lead) min",
                        body: body
                    ))
                }
            }
        }

        // Drop duplicates (overlapping days) and keep the soonest within the limit.
        var seen = Set<String>()
        return alerts
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
}
