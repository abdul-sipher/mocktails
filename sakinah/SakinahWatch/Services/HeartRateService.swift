import Foundation
import HealthKit

/// Reads live heart rate and HRV (SDNN) from HealthKit.
/// On watchOS the heart rate stream updates roughly every few seconds
/// during a workout; we use an HKWorkoutSession-free HKAnchoredObjectQuery
/// which surfaces samples as they are written by the sensor.
final class HeartRateService {
    private let store = HKHealthStore()
    private let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [hrType, hrvType]
        try? await store.requestAuthorization(toShare: [], read: read)
    }

    struct Reading {
        let bpm: Double
        let hrvMs: Double?
        let at: Date
    }

    func stream() -> AsyncStream<Reading> {
        AsyncStream { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-60),
                end: nil, options: .strictStartDate
            )
            let query = HKAnchoredObjectQuery(
                type: hrType, predicate: predicate,
                anchor: nil, limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, _ in
                self.emit(samples: samples, to: continuation)
            }
            query.updateHandler = { _, samples, _, _, _ in
                self.emit(samples: samples, to: continuation)
            }
            self.store.execute(query)
            continuation.onTermination = { _ in self.store.stop(query) }
        }
    }

    private func emit(samples: [HKSample]?, to continuation: AsyncStream<Reading>.Continuation) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        for s in samples {
            continuation.yield(Reading(
                bpm: s.quantity.doubleValue(for: bpmUnit),
                hrvMs: nil,
                at: s.endDate
            ))
        }
    }

    /// Fetches latest HRV SDNN value (may be older than the current moment;
    /// watchOS computes HRV periodically during still periods).
    func latestHRV() async -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(
                sampleType: hrvType, predicate: nil, limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = (samples as? [HKQuantitySample])?.first else {
                    cont.resume(returning: nil); return
                }
                cont.resume(returning: sample.quantity.doubleValue(for: .secondUnit(with: .milli)))
            }
            self.store.execute(q)
        }
    }
}
