import Foundation

/// What a wireless microphone's receiver says about its transmitter. The
/// receiver stays connected over USB when the transmitter is switched off, so
/// this is the only way to know the microphone itself is there.
public struct TransmitterStatus: Equatable, Sendable {
    public var isLinked: Bool
    /// The battery is taking charge right now. A full battery on a charger is not.
    public var isCharging: Bool
    /// The receiver's own battery steps: 1 is full, 7 is nearly empty. Nil when unknown.
    public var gauge: Int?

    public init(isLinked: Bool, isCharging: Bool = false, gauge: Int? = nil) {
        self.isLinked = isLinked
        self.isCharging = isCharging
        self.gauge = gauge
    }

    /// A rough percentage, only to choose which battery mark to draw. The
    /// receiver gives steps, not a percentage, and none is ever shown.
    public var estimatedPercent: Int? {
        gauge.map { [100, 85, 70, 55, 40, 25, 5][min(max($0, 1), 7) - 1] }
    }

    /// The last two steps before the transmitter shuts down.
    public var isLow: Bool { (gauge ?? 1) >= 6 }
}
