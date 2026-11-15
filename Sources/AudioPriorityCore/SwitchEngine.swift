import Foundation

/// Decides which device each role should be on. It holds no reference to
/// CoreAudio: every call is given what the Mac looks like now and returns the
/// switches to make, so the rules can be tested as plain values.
///
/// The rules are those of Audio Priority Bar by Camille Guillory and Tobias
/// Lütke (GPL-3.0), rewritten for this app's smaller scope:
///
/// - Auto on: each role uses the first connected, visible device in its list.
/// - A device the user picks stays until it disconnects or a device ranked
///   above it connects.
/// - When macOS or another app moves the output on its own, as AirPods do,
///   it is switched back once. If macOS takes it again within 30 s it is left
///   there, since each round trip is a gap in the sound.
/// - The microphone is always taken back. Only if it is retaken within a
///   second, three times in a row, does the engine pause for 30 s.
/// - Auto off: devices stay where the user put them. A device the user
///   connects may take the output; the microphone is still held.
public struct SwitchEngine: Sendable {
    public struct Input: Sendable {
        /// Connected, visible devices in rank order: the candidates.
        public var ranking: [Role: [String]]
        /// Every connected device, hidden ones included.
        public var connected: [Role: Set<String>]
        /// The Mac's default device for each role right now.
        public var current: [Role: String]
        /// A monotonic clock, in seconds.
        public var now: TimeInterval
        /// Control Center's Sound module or Sound settings is open, so a
        /// change of default is the user's own pick.
        public var userPicking: Bool

        public init(
            ranking: [Role: [String]], connected: [Role: Set<String>], current: [Role: String],
            now: TimeInterval, userPicking: Bool = false
        ) {
            self.ranking = ranking
            self.connected = connected
            self.current = current
            self.now = now
            self.userPicking = userPicking
        }
    }

    public enum Event: Sendable, Equatable {
        /// CoreAudio reported that devices or defaults changed (also sent at launch).
        case systemChanged
        case userSelected(Role, String)
        case autoChanged(Bool)
        /// The user re-ranked, hid or showed a device of this role.
        case prioritiesChanged(Role)
        /// The 30 s pause after a microphone fight is over.
        case microphonePauseEnded
    }

    public struct Command: Equatable, Sendable {
        public var role: Role
        public var uid: String

        public init(_ role: Role, _ uid: String) {
            self.role = role
            self.uid = uid
        }
    }

    public static let outputRetakeWindow: TimeInterval = 30
    public static let microphoneFastRetake: TimeInterval = 1
    public static let microphonePause: TimeInterval = 30
    private static let arrivalWindow: TimeInterval = 2

    public private(set) var auto: Bool
    /// Auto on: the device the user picked over the list, per role.
    public private(set) var pick: [Role: String] = [:]
    /// Auto off: the device the user left each role on.
    public private(set) var held: [Role: String] = [:]
    /// The device macOS keeps switching to, which the engine has stopped fighting.
    public private(set) var takeover: [Role: String] = [:]
    /// Set while the microphone hold is paused; the caller sends
    /// `.microphonePauseEnded` at this time.
    public private(set) var microphonePauseEndsAt: TimeInterval?

    private var previousConnected: [Role: Set<String>]?
    private var previousCurrent: [Role: String] = [:]
    private var recentlyAdded: [Role: Set<String>] = [:]
    private var topologyChangedAt: [Role: TimeInterval] = [:]
    private var switchedBackAt: [Role: TimeInterval] = [:]
    private var fastMicrophoneRetakes = 0

    public init(auto: Bool) {
        self.auto = auto
    }

    public mutating func handle(_ event: Event, _ input: Input) -> [Command] {
        var commands: [Command] = []
        switch event {
        case .systemChanged:
            for role in Role.allCases {
                if let uid = systemChanged(role, input) { commands.append(Command(role, uid)) }
            }
            previousConnected = input.connected
            previousCurrent = input.current

        case .userSelected(let role, let uid):
            forgetFight(role)
            if auto {
                pick[role] = input.ranking[role]?.first == uid ? nil : uid
            } else {
                held[role] = uid
            }
            if input.current[role] != uid { commands.append(Command(role, uid)) }

        case .autoChanged(let on):
            auto = on
            Role.allCases.forEach { forgetFight($0) }
            pick = [:]
            held = on ? [:] : input.current
            if on {
                for role in Role.allCases {
                    if let target = input.ranking[role]?.first, target != input.current[role] {
                        commands.append(Command(role, target))
                    }
                }
            }

        case .prioritiesChanged(let role):
            forgetFight(role)
            let ranking = input.ranking[role] ?? []
            if auto {
                pick[role] = nil
            } else if let device = held[role], !ranking.contains(device) {
                // The held device was hidden: fall to the list.
                held[role] = ranking.first
            }
            if let target = auto ? ranking.first : held[role], target != input.current[role] {
                commands.append(Command(role, target))
            }

        case .microphonePauseEnded:
            guard takeover[.input] != nil else { break }
            takeover[.input] = nil
            microphonePauseEndsAt = nil
            // A fight still going on pauses again after three more fast retakes.
            switchedBackAt[.input] = input.now
            if let target = desired(.input, input), target != input.current[.input] {
                commands.append(Command(.input, target))
            }
        }
        return commands
    }

    // MARK: A change reported by CoreAudio

    private mutating func systemChanged(_ role: Role, _ input: Input) -> String? {
        let connected = input.connected[role] ?? []
        let ranking = input.ranking[role] ?? []
        let current = input.current[role]
        let isLaunch = previousConnected == nil
        let before = previousConnected?[role] ?? connected
        let arrived = connected.subtracting(before)
        let topologyChanged = arrived != [] || before.subtracting(connected) != []
        if topologyChanged {
            // A device coming or going starts over: the list decides again.
            forgetFight(role)
            topologyChangedAt[role] = input.now
            recentlyAdded[role] = arrived
        }
        let previous = previousCurrent[role]
        let moved = !isLaunch && current != previous
        let justArrived = current.map {
            recentlyAdded[role]?.contains($0) == true && input.now - (topologyChangedAt[role] ?? 0) < Self.arrivalWindow
        } ?? false
        // macOS moves the default itself when a device connects or the current one leaves.
        let explained = topologyChanged || justArrived || previous.map { !connected.contains($0) } == true

        if auto {
            if let picked = pick[role], let rank = ranking.firstIndex(of: picked),
               arrived.contains(where: { ranking.firstIndex(of: $0).map { $0 < rank } == true }) {
                pick[role] = nil
            }
            guard let target = desired(role, input), target != current else { return nil }
            if moved, !explained, let current {
                if input.userPicking {
                    forgetFight(role)
                    pick[role] = ranking.first == current ? nil : current
                    return nil
                }
                return shouldSwitchBack(role, from: current, now: input.now) ? target : nil
            }
            return takeover[role] == current ? nil : target
        }

        // Auto off.
        if isLaunch {
            held[role] = current ?? ranking.first
            return nil
        }
        guard let device = held[role], connected.contains(device) else {
            // Nothing held, or it left: fall to the list.
            held[role] = ranking.first ?? current
            return held[role] == current ? nil : held[role]
        }
        guard let current, current != device else { return nil }
        if moved {
            if role == .output, justArrived {
                // A device the user connects may take the output.
                held[role] = current
                return nil
            }
            if input.userPicking {
                forgetFight(role)
                held[role] = current
                return nil
            }
            if explained { return device }
            return shouldSwitchBack(role, from: current, now: input.now) ? device : nil
        }
        return takeover[role] == current ? nil : device
    }

    /// The device a role should be on, ignoring any fight with macOS.
    private mutating func desired(_ role: Role, _ input: Input) -> String? {
        let connected = input.connected[role] ?? []
        if auto {
            if let picked = pick[role] {
                if connected.contains(picked) { return picked }
                pick[role] = nil
            }
            return input.ranking[role]?.first
        }
        if let device = held[role], connected.contains(device) { return device }
        return input.ranking[role]?.first
    }

    /// Whether to switch `role` back from `uid`, which macOS or another app
    /// just moved it to.
    private mutating func shouldSwitchBack(_ role: Role, from uid: String, now: TimeInterval) -> Bool {
        guard takeover[role] != uid else { return false }
        if role == .input {
            let isFast = switchedBackAt[.input].map { now - $0 < Self.microphoneFastRetake } ?? false
            fastMicrophoneRetakes = isFast ? fastMicrophoneRetakes + 1 : 0
            if fastMicrophoneRetakes >= 3 {
                takeover[.input] = uid
                fastMicrophoneRetakes = 0
                microphonePauseEndsAt = now + Self.microphonePause
                return false
            }
            switchedBackAt[.input] = now
            return true
        }
        if let last = switchedBackAt[role], now - last < Self.outputRetakeWindow {
            takeover[role] = uid
            return false
        }
        switchedBackAt[role] = now
        return true
    }

    private mutating func forgetFight(_ role: Role) {
        takeover[role] = nil
        switchedBackAt[role] = nil
        if role == .input {
            fastMicrophoneRetakes = 0
            microphonePauseEndsAt = nil
        }
    }
}
