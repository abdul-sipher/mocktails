import SwiftUI

struct AyahView: View {
    @EnvironmentObject var session: AppSession
    @State private var ayah: Ayah?

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 10) {
                if let ayah {
                    Text(ayah.arabic)
                        .font(.system(size: 22, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(ayah.translation)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ayah.surahName) · \(ayah.surah):\(ayah.number)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView()
                }
                Button("Another") { reshuffle() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Ayah")
        .onAppear { ayah = session.quran.ayahForCurrentHour() }
    }

    private func reshuffle() { ayah = session.quran.ayahForCurrentHour() }
}
