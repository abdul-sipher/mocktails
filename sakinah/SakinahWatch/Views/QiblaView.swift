import SwiftUI
import Adhan

struct QiblaView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var compass = HeadingService()
    @State private var wasAligned = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let coord = session.lastCoordinate {
                    let qibla = Qibla(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude)).direction
                    dial(qibla: qibla)
                        .frame(width: 140, height: 140)
                    status(qibla: qibla)
                    Text("Qibla \(Int(qibla.rounded()))° \(QiblaMath.cardinal(qibla)) from true north")
                        .font(.caption2).monospacedDigit()
                    Text("Makkah \(Int(QiblaMath.distanceToMakkah(from: coord) / 1000).formatted()) km away")
                        .font(.caption2).foregroundStyle(.secondary)
                    sensorLine
                } else {
                    Text(session.locationDenied
                         ? "Location is off for Sakīnah, so the qibla can't be worked out."
                         : "Awaiting location…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Qibla")
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
    }

    /// The dial turns with the watch so north stays north; the Kaʿbah
    /// marker sits at the qibla bearing; the fixed tick at the top is
    /// where the watch points.
    private func dial(qibla: Double) -> some View {
        let heading = compass.heading ?? 0
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 2)
            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(.system(size: 13, weight: label == "N" ? .bold : .regular))
                    .foregroundStyle(label == "N" ? Color.red : Color.secondary)
                    // Counter-rotate so letters stay upright as the dial turns.
                    .rotationEffect(.degrees(-Double(i) * 90 + heading))
                    .offset(y: -58)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
            Image(systemName: "building.columns.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.85, green: 0.7, blue: 0.3))
                .offset(y: -42)
                .rotationEffect(.degrees(qibla))
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-heading))
        .overlay(alignment: .top) {
            Capsule().fill(isAligned(qibla) ? Color.green : Color.primary)
                .frame(width: 4, height: 14)
                .offset(y: -4)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: heading)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText(qibla: qibla))
    }

    @ViewBuilder private func status(qibla: Double) -> some View {
        if compass.heading != nil {
            switch QiblaMath.turn(qibla: qibla, heading: compass.heading ?? 0) {
            case .aligned:
                Label("Facing qibla", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.green)
                    .onAppear { buzzOnAlign(true) }
            case .left(let d):
                Text("Turn left \(Int(d.rounded()))°").font(.headline)
                    .onAppear { buzzOnAlign(false) }
            case .right(let d):
                Text("Turn right \(Int(d.rounded()))°").font(.headline)
                    .onAppear { buzzOnAlign(false) }
            }
        }
    }

    @ViewBuilder private var sensorLine: some View {
        if !compass.isAvailable {
            Text("This watch has no compass, so only the bearing is shown. Use it with any compass.")
                .font(.caption2).foregroundStyle(.orange).multilineTextAlignment(.center)
        } else if compass.heading == nil {
            Text("Waiting for compass…").font(.caption2).foregroundStyle(.secondary)
        } else {
            let source = compass.source == .trueNorth ? "True north" : "Magnetic north (approximate)"
            let acc = compass.accuracy.map { " · ±\(Int($0))°" } ?? ""
            Text(source + acc).font(.caption2)
                .foregroundStyle((compass.accuracy ?? 0) > 20 ? Color.orange : Color.secondary)
            if (compass.accuracy ?? 0) > 20 {
                Text("Low accuracy: move away from metal and wave the watch in a figure of eight.")
                    .font(.caption2).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
        }
    }

    private func isAligned(_ qibla: Double) -> Bool {
        guard let h = compass.heading else { return false }
        return QiblaMath.turn(qibla: qibla, heading: h) == .aligned
    }

    private func buzzOnAlign(_ aligned: Bool) {
        if aligned && !wasAligned && session.settings.settings.qiblaHaptic {
            session.haptic.play(.wuduComplete)
        }
        wasAligned = aligned
    }

    private func accessibilityText(qibla: Double) -> String {
        guard let h = compass.heading else { return "Qibla bearing \(Int(qibla)) degrees" }
        switch QiblaMath.turn(qibla: qibla, heading: h) {
        case .aligned: return "Facing qibla"
        case .left(let d): return "Turn left \(Int(d)) degrees"
        case .right(let d): return "Turn right \(Int(d)) degrees"
        }
    }
}
