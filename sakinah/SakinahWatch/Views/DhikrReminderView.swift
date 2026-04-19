import SwiftUI

/// Surfaced when AnxietyDetector fires. Gentle suggestion to pause and
/// make dhikr. Shown as a sheet on Home when `session.dhikrReminderActive`.
struct DhikrReminderView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        VStack(spacing: 10) {
            Text("﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾")
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
            Text("Verily, in the remembrance of Allah do hearts find rest.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Ar-Raʿd 13:28").font(.caption2).foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                dhikrLine("سُبْحَانَ اللَّهِ")
                dhikrLine("الْحَمْدُ لِلَّهِ")
                dhikrLine("اللَّهُ أَكْبَرُ")
            }
            .padding(.top, 4)

            Button("Alhamdulillah") { session.dhikrReminderActive = false }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
        .padding()
    }

    private func dhikrLine(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
