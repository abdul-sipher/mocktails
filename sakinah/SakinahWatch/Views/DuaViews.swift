import SwiftUI
import WatchKit

// MARK: - Du'a library

struct DuaLibraryView: View {
    @EnvironmentObject var session: AppSession
    @State private var favourites = DuaFavourites.load()

    var body: some View {
        List {
            let favs = session.duaLibrary.duas.filter { favourites.contains($0.id) }
            if !favs.isEmpty {
                Section("Favourites") {
                    ForEach(favs) { d in NavigationLink(d.title) { DuaReadingView(dua: d) } }
                }
            }
            Section {
                ForEach(DuaCategory.allCases) { c in
                    NavigationLink {
                        DuaCategoryView(category: c)
                    } label: {
                        Label(c.title, systemImage: c.symbol)
                    }
                }
            } footer: {
                Text("Arabic with sources. Meanings are plain English renderings. Awaiting scholar review.")
            }
        }
        .navigationTitle("Duʿas")
        .onAppear { favourites = DuaFavourites.load() }
    }
}

struct DuaCategoryView: View {
    let category: DuaCategory
    @EnvironmentObject var session: AppSession

    var body: some View {
        List(session.duaLibrary.duas(in: category)) { d in
            NavigationLink { DuaReadingView(dua: d) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.title).font(.footnote.weight(.semibold))
                    Text(d.reference).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category.title)
    }
}

/// Large Arabic, then transliteration, meaning and source; scrolls with the Crown.
struct DuaReadingView: View {
    let dua: Dua
    @State private var favourite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // In a right-to-left environment "leading" is the right edge.
                Text(dua.arabic)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityLabel(dua.transliteration)
                Text(dua.transliteration).font(.caption).italic().foregroundStyle(.secondary)
                Text(dua.meaning).font(.footnote)
                Text(dua.reference + (dua.excerpt ? " · excerpt" : ""))
                    .font(.caption2).foregroundStyle(.secondary)
                if let count = dua.count, count > 1 {
                    Text("× \(count)").font(.caption2.bold()).foregroundStyle(.green)
                }
                Button {
                    favourite.toggle()
                    var ids = DuaFavourites.load()
                    if favourite { ids.insert(dua.id) } else { ids.remove(dua.id) }
                    DuaFavourites.save(ids)
                } label: {
                    Label(favourite ? "Favourite" : "Add to favourites", systemImage: favourite ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(dua.title)
        .onAppear { favourite = DuaFavourites.load().contains(dua.id) }
    }
}

// MARK: - Adhkar

struct AdhkarHubView: View {
    var body: some View {
        List {
            ForEach(AdhkarSet.allCases) { s in
                NavigationLink(s.title) { AdhkarView(set: s) }
            }
            NavigationLink { TasbihView() } label: { Label("Tasbih counter", systemImage: "circle.dotted") }
        }
        .navigationTitle("Adhkar")
    }
}

/// Each dhikr counts down with a tap; the row turns green when done.
struct AdhkarView: View {
    let set: AdhkarSet
    @EnvironmentObject var session: AppSession
    @State private var remaining: [String: Int] = [:]

    var body: some View {
        List {
            ForEach(session.duaLibrary.adhkar(in: set)) { d in
                let left = remaining[d.id] ?? (d.count ?? 1)
                Button {
                    guard left > 0 else { return }
                    remaining[d.id] = left - 1
                    WKInterfaceDevice.current().play(left - 1 == 0 ? .success : .click)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(d.arabic)
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(d.transliteration).font(.caption2).foregroundStyle(.secondary)
                        HStack {
                            Text(d.reference).font(.system(size: 10)).foregroundStyle(.secondary)
                            Spacer()
                            Text(left == 0 ? "Done" : "\(left) left")
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(left == 0 ? .green : .primary)
                        }
                    }
                }
                .accessibilityLabel("\(d.title), \(left) left")
            }
            Button("Start again") { remaining = [:] }.font(.caption)
        }
        .navigationTitle(set.title)
    }
}

// MARK: - Tasbih

struct TasbihView: View {
    @State private var crown = 0.0
    @State private var count = 0
    @State private var target = 33
    @State private var phrase = 0

    private let phrases = [("سُبْحَانَ اللَّهِ", "SubhanAllah"), ("الْحَمْدُ لِلَّهِ", "Alhamdulillah"),
                           ("اللَّهُ أَكْبَرُ", "Allahu akbar"), ("أَسْتَغْفِرُ اللَّهَ", "Astaghfirullah"),
                           ("لَا إِلَٰهَ إِلَّا اللَّهُ", "La ilaha illallah")]

    var body: some View {
        VStack(spacing: 4) {
            Text(phrases[phrase].0).font(.system(size: 18, weight: .medium))
            Text(phrases[phrase].1).font(.caption2).foregroundStyle(.secondary)
            Button {
                increment()
            } label: {
                Text("\(count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(count) of \(target)")
            .accessibilityHint("Tap or turn the Digital Crown to count")
            Text("of \(target)").font(.caption2).foregroundStyle(.secondary)
            HStack {
                Button { phrase = (phrase + 1) % phrases.count; count = 0 } label: { Image(systemName: "text.bubble") }
                    .accessibilityLabel("Next phrase")
                Button { target = target == 33 ? 99 : (target == 99 ? 100 : 33) } label: { Text("\(target)") }
                    .accessibilityLabel("Target \(target)")
                Button { count = 0 } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("Reset")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .focusable()
        .digitalCrownRotation($crown, from: -1_000_000, through: 1_000_000, by: 1, sensitivity: .low,
                              isContinuous: true, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { old, new in
            // One count per whole step forward of the Crown.
            if Int(new) > Int(old) { increment() }
        }
        .navigationTitle("Tasbih")
    }

    private func increment() {
        count += 1
        if count % target == 0 {
            WKInterfaceDevice.current().play(.success)
        } else if count % 33 == 0 {
            WKInterfaceDevice.current().play(.notification)
        } else {
            WKInterfaceDevice.current().play(.click)
        }
    }
}
