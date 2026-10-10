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
                    NextPrayerCard(next: session.nextPrayer)
                    AyahCard(ayah: session.currentAyah)
                    TileGrid()
                    MosqueSuggestionCard(mosque: session.nearestMosque)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
            .navigationTitle("Sakīnah")
        }
        .sheet(isPresented: $session.dhikrReminderActive) {
            DhikrReminderView()
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
    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
            NavigationLink { WuduView() } label: { Tile(title: "Wudu", systemImage: "drop.fill", tint: .teal) }
            NavigationLink { SalahStartView() } label: { Tile(title: "Salah", systemImage: "figure.stand", tint: .green) }
            NavigationLink { AyahView() } label: { Tile(title: "Ayah", systemImage: "text.book.closed.fill", tint: .indigo) }
            NavigationLink { MosqueFinderView() } label: { Tile(title: "Mosques", systemImage: "mappin.and.ellipse", tint: .orange) }
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
            Text(title).font(.footnote.weight(.medium))
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct NextPrayerCard: View {
    let next: PrayerTime?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXT PRAYER").font(.caption2).foregroundStyle(.secondary).tracking(2)
            if let next {
                HStack {
                    Text(next.name.title).font(.headline)
                    Spacer()
                    Text(next.date, style: .time).font(.headline.monospacedDigit())
                }
                Text(next.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Awaiting location…").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
