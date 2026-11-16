import Foundation

/// What a wireless microphone's receiver says about its transmitter. The
/// receiver stays connected over USB when the transmitter is switched off, so
/// this is the only way to know the microphone itself is there.
public struct TransmitterStatus: Equatable, Sendable {
    public var isLinked: Bool
    public var isMuted: Bool
    public var isCharging: Bool
    /// The receiver's own battery steps: 1 is full, 7 is nearly empty. Nil when unknown.
    public var gauge: Int?

    public init(isLinked: Bool, isMuted: Bool = false, isCharging: Bool = false, gauge: Int? = nil) {
        self.isLinked = isLinked
        self.isMuted = isMuted
        self.isCharging = isCharging
        self.gauge = gauge
    }

    /// A rough percentage for the battery mark. The receiver gives steps, not a percentage.
    public var estimatedPercent: Int? {
        gauge.map { [100, 85, 70, 55, 40, 25, 5][min(max($0, 1), 7) - 1] }
    }

    public var word: String? {
        gauge.map { ["Full", "High", "High", "Medium", "Medium", "Low", "Very low"][min(max($0, 1), 7) - 1] }
    }

    public var isLow: Bool { (gauge ?? 1) >= 6 }
}
