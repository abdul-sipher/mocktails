import SwiftUI
import CoreLocation
import MapKit

struct MosqueFinderView: View {
    @EnvironmentObject var session: AppSession
    @State private var library = MosqueLibrary.load()
    @State private var results: [Mosque] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showingCache = false

    var body: some View {
        List {
            if library.home != nil || library.work != nil {
                Section("My places") {
                    if let home = library.home { link(home, badge: "house.fill") }
                    if let work = library.work { link(work, badge: "briefcase.fill") }
                }
            }
            if !library.favourites.isEmpty {
                Section("Favourites") {
                    ForEach(library.favourites) { link($0, badge: "star.fill") }
                }
            }
            Section {
                if loading && results.isEmpty {
                    HStack { ProgressView(); Text("Searching…").font(.footnote) }
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
                ForEach(results) { link($0, badge: nil) }
                if !loading && results.isEmpty && error == nil && session.lastCoordinate != nil {
                    Text("No mosques or prayer halls found within 5 km.").font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Nearby")
            } footer: {
                if showingCache, let at = library.cachedAt {
                    Text("Saved results from \(at.formatted(date: .abbreviated, time: .shortened)); may be out of date.")
                } else {
                    Text("From Apple Maps. Iqamah and Jumuʿah times are not available.")
                }
            }
        }
        .navigationTitle("Mosques")
        .task(id: session.lastCoordinate.map { "\($0.latitude),\($0.longitude)" }) { await load() }
        .onAppear { library = MosqueLibrary.load() }
    }

    private func link(_ m: Mosque, badge: String?) -> some View {
        NavigationLink {
            MosqueDetailView(mosque: m, library: $library)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let badge { Image(systemName: badge).font(.caption2).foregroundStyle(.orange) }
                    Text(m.name).font(.footnote.weight(.semibold)).lineLimit(2)
                }
                Text(distanceText(m)).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func distanceText(_ m: Mosque) -> String {
        let d = session.lastCoordinate.map { m.distance(from: $0) } ?? m.distanceMeters
        return d < 1000 ? "\(Int(d)) m" : String(format: "%.1f km", d / 1000)
    }

    private func load() async {
        guard let coord = session.lastCoordinate else { return }
        loading = true
        defer { loading = false }
        do {
            results = try await session.mosques.nearby(to: coord)
            error = nil
            showingCache = false
            library.cached = Array(results.prefix(25))
            library.cachedAt = Date()
            library.save()
        } catch {
            if !library.cached.isEmpty {
                results = library.cached
                showingCache = true
                self.error = "Couldn't reach Apple Maps; showing saved results."
            } else {
                self.error = "Could not load nearby mosques. Check your connection."
            }
        }
    }
}

struct MosqueDetailView: View {
    let mosque: Mosque
    @Binding var library: MosqueLibrary
    @EnvironmentObject var session: AppSession
    @State private var walk: TimeInterval?
    @State private var drive: TimeInterval?
    @State private var etaLoaded = false

    var body: some View {
        List {
            Section {
                Text(mosque.name).font(.headline)
                if let coord = session.lastCoordinate {
                    LabeledContent("Distance", value: format(distance: mosque.distance(from: coord)))
                }
                LabeledContent("Walking", value: etaText(walk))
                LabeledContent("Driving", value: etaText(drive))
            }

            if let advice {
                Section("Can I make it?") {
                    Text(advice.headline).font(.footnote)
                        .foregroundStyle(advice.canMakeStart ? Color.green : Color.primary)
                }
            }

            Section {
                Button { session.mosques.openDirections(to: mosque, walking: true) } label: {
                    Label("Walking directions", systemImage: "figure.walk")
                }
                Button { session.mosques.openDirections(to: mosque, walking: false) } label: {
                    Label("Driving directions", systemImage: "car.fill")
                }
            }

            Section {
                Button {
                    library.toggleFavourite(mosque); library.save()
                } label: {
                    Label(library.isFavourite(mosque) ? "Remove favourite" : "Add to favourites",
                          systemImage: library.isFavourite(mosque) ? "star.slash" : "star")
                }
                Button {
                    library.home = library.home == mosque ? nil : mosque; library.save()
                } label: {
                    Label(library.home == mosque ? "Unset home mosque" : "Set as home mosque", systemImage: "house")
                }
                Button {
                    library.work = library.work == mosque ? nil : mosque; library.save()
                } label: {
                    Label(library.work == mosque ? "Unset work mosque" : "Set as work mosque", systemImage: "briefcase")
                }
            }

            Section {
                LabeledContent("Iqamah", value: "Not available")
                LabeledContent("Jumuʿah", value: "Not available")
                if let phone = mosque.phoneNumber {
                    LabeledContent("Phone", value: phone)
                }
            } footer: {
                Text("No verified source for congregation times yet. Check with the mosque.")
            }
        }
        .navigationTitle("Mosque")
        .task {
            guard let coord = session.lastCoordinate else { return }
            async let w = session.mosques.travelTime(from: coord, to: mosque, by: .walking)
            async let d = session.mosques.travelTime(from: coord, to: mosque, by: .automobile)
            (walk, drive) = await (w, d)
            etaLoaded = true
        }
    }

    private var advice: ArrivalAdvice.Advice? {
        guard let next = session.nextPrayer else { return nil }
        let now = Date()
        // Prefer advice about the current window if one is open, else the next prayer.
        if let w = session.currentWindow {
            return ArrivalAdvice.advise(prayer: w.prayer, prayerStart: w.start, windowEnd: w.preferredEnd ?? w.end,
                                        travel: walk ?? drive, mode: walk != nil ? "Walking" : "Driving", now: now)
                ?? ArrivalAdvice.advise(prayer: next.name, prayerStart: next.date, windowEnd: nil,
                                        travel: walk ?? drive, mode: walk != nil ? "Walking" : "Driving", now: now)
        }
        return ArrivalAdvice.advise(prayer: next.name, prayerStart: next.date, windowEnd: nil,
                                    travel: walk ?? drive, mode: walk != nil ? "Walking" : "Driving", now: now)
    }

    private func etaText(_ t: TimeInterval?) -> String {
        guard let t else { return etaLoaded ? "Unavailable" : "…" }
        return "\(max(1, Int((t / 60).rounded(.up)))) min"
    }

    private func format(distance d: CLLocationDistance) -> String {
        d < 1000 ? "\(Int(d)) m" : String(format: "%.1f km", d / 1000)
    }
}
