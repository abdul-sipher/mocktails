import Foundation
import CoreMotion

/// Streams CoreMotion samples for posture detection.
/// Uses device motion (attitude + gravity + user accel) at 50Hz and
/// relative altitude from the barometer for sujood disambiguation.
final class MotionService {
    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let queue = OperationQueue()

    struct Sample {
        let timestamp: TimeInterval
        let pitch: Double         // radians
        let roll: Double          // radians
        let gravityX: Double
        let gravityY: Double
        let gravityZ: Double
        let userAccelMag: Double  // |a| without gravity, g-units
        let rotationMag: Double   // |ω|, rad/s
        let relativeAltitude: Double  // meters, relative to stream start
    }

    private(set) var lastAltitude: Double = 0
    private var continuation: AsyncStream<Sample>.Continuation?

    func stream() -> AsyncStream<Sample> {
        AsyncStream { continuation in
            self.continuation = continuation
            start()
            continuation.onTermination = { [weak self] _ in self?.stop() }
        }
    }

    private func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: queue) { [weak self] dm, _ in
            guard let self, let dm else { return }
            let sample = Sample(
                timestamp: dm.timestamp,
                pitch: dm.attitude.pitch,
                roll: dm.attitude.roll,
                gravityX: dm.gravity.x,
                gravityY: dm.gravity.y,
                gravityZ: dm.gravity.z,
                userAccelMag: sqrt(
                    dm.userAcceleration.x * dm.userAcceleration.x +
                    dm.userAcceleration.y * dm.userAcceleration.y +
                    dm.userAcceleration.z * dm.userAcceleration.z
                ),
                rotationMag: sqrt(
                    dm.rotationRate.x * dm.rotationRate.x +
                    dm.rotationRate.y * dm.rotationRate.y +
                    dm.rotationRate.z * dm.rotationRate.z
                ),
                relativeAltitude: self.lastAltitude
            )
            self.continuation?.yield(sample)
        }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
                guard let data else { return }
                self?.lastAltitude = data.relativeAltitude.doubleValue
            }
        }
    }

    private func stop() {
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}
