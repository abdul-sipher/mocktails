import Foundation
import HealthKit

/// Saves a finished salah as mindful minutes in Health, only when the
/// user has switched this on.
final class MindfulService {
    private let store = HKHealthStore()
    private let type = HKCategoryType(.mindfulSession)

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [type], read: [])
            return store.authorizationStatus(for: type) == .sharingAuthorized
        } catch { return false }
    }

    func save(start: Date, end: Date) async {
        guard HKHealthStore.isHealthDataAvailable(), end > start,
              store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let sample = HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        try? await store.save(sample)
    }
}
