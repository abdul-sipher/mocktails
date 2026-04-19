import SwiftUI
import CoreLocation

struct MosqueFinderView: View {
    @EnvironmentObject var session: AppSession
    @State private var mosques: [Mosque] = []
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            ForEach(mosques) { m in
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.name).font(.footnote.weight(.semibold))
                    Text("\(Int(m.distanceMeters)) m").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Mosques")
        .task { await load() }
    }

    private func load() async {
        for await coord in session.location.stream() {
            do {
                mosques = try await session.mosques.nearby(to: coord)
            } catch {
                self.error = "Could not load nearby mosques."
            }
            break
        }
    }
}
