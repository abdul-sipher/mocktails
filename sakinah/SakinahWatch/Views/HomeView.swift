import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if session.mosqueNudgeActive, let next = session.nextPrayer, let mosque = session.nearestMosque {
                        MosqueNudgeCard(next: next, mosque: mosque)
                    }
                    Text(HijriDate.string(for: Date(), offsetDays: session.settings.settings.hijriOffset))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if HijriDate.isRamadan(Date(), offsetDays: session.settings.settings.hijriOffset),
                       let t = session.timetable {
                        RamadanCard(timetable: t)
                    }
                    NextPrayerCard()
                    if let timetable = session.timetable, let next = session.nextPrayer {
                        TodayStrip(timetable: timetable, next: next)
                    }
                    if let since = session.wuduSince {
                        WuduChip(since: since) { session.setWudu(false) }
                    }
                    AyahCard(ayah: session.currentAyah)
                    TileGrid()
                    MosqueSuggestionCard(mosque: session.nearestMosque)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
            .navigationTitle("Sakīnah")
        }
        .sheet(item: $session.activeSheet) { sheet in
            switch sheet {
            case .methodPrompt:
                MethodPromptView(store: session.settings) {
                    session.activeSheet = nil
                    Task { await session.prepareAlerts() }
                }
            case .dhikr:
                DhikrReminderView()
            }
        }
    }
}

/// "Dhuhr in 8 min — pray at Masjid X (240 m)?" shown in the 10 minutes before a prayer.
private struct MosqueNudgeCard: View {
    let next: PrayerTime
    let mosque: Mosque

    var body: some View {
        NavigationLink {
            MosqueFinderView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill").foregroundStyle(.orange)
                // Own timeline: the card's inputs don't change as the minutes tick down.
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text("\(next.name.title) in \(minutesLeft(at: context.date)) min — pray at \(mosque.name) (\(Int(mosque.distanceMeters)) m)?")
                        .font(.footnote.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func minutesLeft(at now: Date) -> Int {
        max(1, Int(next.date.timeIntervalSince(now) / 60))
    }
}

private struct TileGrid: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
            NavigationLink { WuduView() } label: { Tile(title: "Wudu", systemImage: "drop.fill", tint: .teal) }
            NavigationLink { SalahStartView() } label: { Tile(title: "Salah", systemImage: "figure.stand", tint: .green) }
            NavigationLink { AyahView() } label: { Tile(title: "Qurʾan", systemImage: "text.book.closed.fill", tint: .indigo) }
            NavigationLink { DuaLibraryView() } label: { Tile(title: "Duʿas", systemImage: "hands.and.sparkles.fill", tint: .mint) }
            NavigationLink { AdhkarHubView() } label: { Tile(title: "Adhkar", systemImage: "circle.dotted", tint: .green) }
            NavigationLink { MosqueFinderView() } label: { Tile(title: "Mosques", systemImage: "mappin.and.ellipse", tint: .orange) }
            NavigationLink { QiblaView() } label: { Tile(title: "Qibla", systemImage: "location.north.line.fill", tint: Color(red: 0.85, green: 0.7, blue: 0.3)) }
            NavigationLink { HistoryView() } label: { Tile(title: "History", systemImage: "checklist", tint: .teal) }
            NavigationLink { TimetableView() } label: { Tile(title: "Timetable", systemImage: "clock.fill", tint: .cyan) }
            NavigationLink { SettingsView(store: session.settings) } label: { Tile(title: "Settings", systemImage: "gearshape.fill", tint: .gray) }
        }
        .buttonStyle(.plain)
    }
}

private struct Tile: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.title3).foregroundStyle(tint)
            Text(LocalizedStringKey(title)).font(.footnote.weight(.medium))
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct NextPrayerCard: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXT PRAYER").font(.caption2).foregroundStyle(.secondary).tracking(2)
            if let next = session.nextPrayer {
                HStack {
                    Text(next.name.displayTitle(isFriday: session.timetable?.isFriday == true && Calendar.current.isDateInToday(next.date)))
                        .font(.headline)
                    Spacer()
                    Text(next.date, style: .time).font(.headline.monospacedDigit())
                }
                Text(next.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                Text(windowLine).font(.caption2).foregroundStyle(.green)
            } else if session.locationDenied {
                Text("Location is off for Sakīnah. Turn it on in the Watch app ▸ Privacy ▸ Location to see prayer times.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if session.timesUnavailable {
                Text("Times unavailable today at this latitude. Change the high-latitude rule in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Awaiting location…").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var windowLine: String {
        guard let w = session.currentWindow else { return "No prayer due now" }
        let end = (w.preferredEnd ?? w.end).formatted(date: .omitted, time: .shortened)
        let name = w.prayer.title
        return w.preferredEnd == nil ? "\(name) time until \(end)" : "\(name) time, best before \(end)"
    }
}

/// Today's five prayers; the next one highlighted.
private struct TodayStrip: View {
    let timetable: DayTimetable
    let next: PrayerTime

    var body: some View {
        VStack(spacing: 3) {
            ForEach(timetable.prayers, id: \.name) { p in
                HStack {
                    Text(p.name.displayTitle(isFriday: timetable.isFriday))
                    Spacer()
                    Text(p.date, style: .time).monospacedDigit()
                }
                .font(.caption.weight(p.date == next.date ? .bold : .regular))
                .foregroundStyle(p.date == next.date ? Color.green : (p.date < Date() ? Color.secondary : Color.primary))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AyahCard: View {
    let ayah: Ayah?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AYAH OF THE HOUR").font(.caption2).foregroundStyle(.secondary).tracking(2)
            if let ayah {
                Text(ayah.arabic).font(.system(size: 16, weight: .medium)).multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
                Text(ayah.translation).font(.caption).foregroundStyle(.primary)
                Text("\(ayah.surahName) · \(ayah.surah):\(ayah.number)").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Loading…").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MosqueSuggestionCard: View {
    let mosque: Mosque?

    var body: some View {
        guard let mosque else {
            return AnyView(EmptyView())
        }
        return AnyView(
            NavigationLink {
                MosqueFinderView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mosque.name).font(.footnote.weight(.semibold)).lineLimit(1)
                        Text("\(Int(mosque.distanceMeters)) m away").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        )
    }
}

/// Shown while the user has marked that they have wudu.
private struct WuduChip: View {
    let since: Date
    let clear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "drop.fill").foregroundStyle(.teal)
            Text("Wudu marked \(since.formatted(date: .omitted, time: .shortened))").font(.caption2)
            Spacer()
            Button("Clear", action: clear).font(.caption2).buttonStyle(.plain).foregroundStyle(.teal)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Suhoor ends at Fajr; iftar at Maghrib. Counts down to whichever is next.
private struct RamadanCard: View {
    let timetable: DayTimetable

    var body: some View {
        let now = Date()
        let iftarNext = now >= timetable.fajr && now < timetable.maghrib
        let target = iftarNext ? timetable.maghrib : (now < timetable.fajr ? timetable.fajr : timetable.nextFajr)
        VStack(alignment: .leading, spacing: 2) {
            Text("RAMADAN").font(.caption2).foregroundStyle(.secondary).tracking(2)
            HStack {
                Text(iftarNext ? "Iftar" : "Suhoor ends").font(.headline)
                Spacer()
                Text(target, style: .time).font(.headline.monospacedDigit())
            }
            Text(target, style: .relative).font(.caption2).foregroundStyle(.secondary)
            Text(iftarNext ? "At Maghrib" : "At Fajr. Many timetables stop eating a few minutes earlier.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.85, green: 0.7, blue: 0.3).opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }
}
