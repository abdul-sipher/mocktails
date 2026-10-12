import SwiftUI

/// Shown when calm reminders are on and heart rate suggests a moment of
/// agitation. Worded as an invitation, never a diagnosis.
struct DhikrReminderView: View {
    @EnvironmentObject var session: AppSession

    /// Verified texts rotated through (ids in Duas.json, plus 13:28).
    private static let duaIDs = ["anger-restrain", "anger-strong", "distress-hasbuna"]
    @State private var pick = Int.random(in: 0...DhikrReminderView.duaIDs.count)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("A moment to pause?").font(.headline)
                if pick < Self.duaIDs.count, let d = session.duaLibrary.dua(id: Self.duaIDs[pick]) {
                    passage(arabic: d.arabic, english: d.meaning, source: d.reference + (d.excerpt ? " · excerpt" : ""))
                } else {
                    passage(arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
                            english: "Truly, in the remembrance of Allah do hearts find rest.",
                            source: "Qur'an 13:28 · excerpt")
                }

                VStack(spacing: 4) {
                    dhikrLine("سُبْحَانَ اللَّهِ")
                    dhikrLine("الْحَمْدُ لِلَّهِ")
                    dhikrLine("اللَّهُ أَكْبَرُ")
                }

                Text("Your heart rate was raised. That can mean many things, and this is only a suggestion.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Button("That helped") {
                    session.calmFeedback(helpful: true)
                    session.activeSheet = nil
                }
                .buttonStyle(.borderedProminent).tint(.indigo)
                Button("Not helpful right now") {
                    session.calmFeedback(helpful: false)
                    session.activeSheet = nil
                }
                .font(.caption)
            }
            .padding(.horizontal, 4)
        }
    }

    private func passage(arabic: String, english: String, source: String) -> some View {
        VStack(spacing: 4) {
            Text(arabic)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            Text(english).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(source).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func dhikrLine(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
