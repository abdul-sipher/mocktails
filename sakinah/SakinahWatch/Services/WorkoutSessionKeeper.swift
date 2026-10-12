import Foundation
import HealthKit

/// Runs a quiet "Mind and Body" workout session during automatic salah
/// tracking so watchOS keeps the app and motion sensors running when the
/// wrist drops in ruku and sujood. No workout is saved to Health.
final class WorkoutSessionKeeper {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?

    /// Returns false when Health is unavailable or permission is refused;
    /// tracking then continues, but the screen may sleep.
    func start() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            let config = HKWorkoutConfiguration()
            config.activityType = .mindAndBody
            config.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            session.startActivity(with: Date())
            self.session = session
            return true
        } catch {
            return false
        }
    }

    func stop() {
        session?.end()
        session = nil
    }
}
