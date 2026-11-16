import Foundation

/// Everything the app remembers, saved as one JSON value.
public struct Settings: Codable, Equatable, Sendable {
    /// Device UIDs in rank order, per list, including disconnected and hidden ones.
    public var order: [String: [String]] = [:]
    /// `DeviceID.key` of each hidden device.
    public var hidden: Set<String> = []
    /// `DeviceID.key` to what is needed to list the device while it is away.
    public var known: [String: KnownDevice] = [:]
    public var auto = true
    public var launchAtLogin = true
    /// The app has added itself to Login Items, so finding itself gone from
    /// them means the user took it out in System Settings.
    public var loginItemRegistered = false

    public init() {}

    /// A field missing from older or newer saved settings takes its default,
    /// so adding one never throws the lists away.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        order = try values.decodeIfPresent([String: [String]].self, forKey: .order) ?? [:]
        hidden = try values.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? []
        known = try values.decodeIfPresent([String: KnownDevice].self, forKey: .known) ?? [:]
        auto = try values.decodeIfPresent(Bool.self, forKey: .auto) ?? true
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        loginItemRegistered = try values.decodeIfPresent(Bool.self, forKey: .loginItemRegistered) ?? false
    }
}

/// The ranked lists and the hidden set. A hidden device keeps its rank.
@MainActor
public final class PriorityStore {
    private static let key = "settings"
    private let defaults: UserDefaults
    public private(set) var settings: Settings

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.key) else {
            settings = Settings()
            return
        }
        do {
            settings = try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            // Start over, but keep what could not be read: the next save would
            // otherwise replace the ranked lists for good.
            settings = Settings()
            if defaults.data(forKey: Self.unreadableKey) == nil { defaults.set(data, forKey: Self.unreadableKey) }
        }
    }

    /// Where settings that could not be read are kept, for recovery by hand.
    public static let unreadableKey = "settings.unreadable"

    private func save() {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
    }

    /// True until the first device has been remembered.
    public var isEmpty: Bool { settings.known.isEmpty }

    // MARK: Remembering devices

    /// Remembers devices, new ones at the bottom of their list in the order
    /// given, and refreshes what is known about the ones already there.
    public func register(_ devices: [AudioDevice]) {
        var changed = false
        for device in devices {
            let key = device.id.key
            var known = KnownDevice(
                name: device.name, transport: device.transport, category: device.category,
                bluetoothAddress: device.bluetoothAddress, productID: device.productID
            )
            if let old = settings.known[key] {
                // The list a device is in is the user's to change, so it is never refreshed.
                known.category = old.category
                known.productID = device.productID ?? old.productID
            } else {
                settings.order[known.category.rawValue, default: []].append(device.uid)
            }
            if settings.known[key] != known {
                settings.known[key] = known
                changed = true
            }
        }
        if changed { save() }
    }

    public func category(of id: DeviceID) -> DeviceCategory? {
        settings.known[id.key]?.category
    }

    /// Every remembered device of a role in rank order, connected ones as
    /// CoreAudio describes them and the rest from memory.
    public func devices(for role: Role, connected: [AudioDevice]) -> [AudioDevice] {
        let live = Dictionary(connected.filter { $0.role == role }.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        return DeviceCategory.categories(for: role).flatMap { category in
            (settings.order[category.rawValue] ?? []).compactMap { uid -> AudioDevice? in
                let id = DeviceID(role, uid)
                guard let known = settings.known[id.key] else { return nil }
                if var device = live[uid] {
                    device.category = category
                    device.productID = device.productID ?? known.productID
                    return device
                }
                return AudioDevice(
                    id: id, name: known.name, transport: known.transport, category: category,
                    isConnected: false, bluetoothAddress: known.bluetoothAddress, productID: known.productID
                )
            }
        }
    }

    // MARK: Hiding

    public func isHidden(_ id: DeviceID) -> Bool { settings.hidden.contains(id.key) }

    public func setHidden(_ id: DeviceID, _ hidden: Bool) {
        if hidden { settings.hidden.insert(id.key) } else { settings.hidden.remove(id.key) }
        save()
    }

    // MARK: Ranking

    /// Moves a device to `index` among the visible devices of its list.
    public func move(_ id: DeviceID, toVisibleIndex index: Int) {
        guard let category = category(of: id) else { return }
        var uids = settings.order[category.rawValue] ?? []
        guard let from = uids.firstIndex(of: id.uid) else { return }
        uids.remove(at: from)
        let visible = uids.filter { !isHidden(DeviceID(id.role, $0)) }
        if index >= visible.count {
            // After the last visible device, ahead of any hidden ones below it.
            let last = visible.last.flatMap(uids.firstIndex(of:))
            uids.insert(id.uid, at: last.map { $0 + 1 } ?? uids.count)
        } else {
            uids.insert(id.uid, at: uids.firstIndex(of: visible[max(index, 0)]) ?? 0)
        }
        settings.order[category.rawValue] = uids
        save()
    }

    /// Moves an output between Headphones and Speakers, to the bottom of the other list.
    public func setCategory(_ category: DeviceCategory, for id: DeviceID) {
        guard id.role == .output, category.role == .output,
              var known = settings.known[id.key], known.category != category else { return }
        settings.order[known.category.rawValue]?.removeAll { $0 == id.uid }
        settings.order[category.rawValue, default: []].append(id.uid)
        known.category = category
        settings.known[id.key] = known
        save()
    }

    // MARK: Switches

    public var auto: Bool {
        get { settings.auto }
        set { settings.auto = newValue; save() }
    }

    public var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set { settings.launchAtLogin = newValue; save() }
    }

    public var loginItemRegistered: Bool {
        get { settings.loginItemRegistered }
        set {
            guard newValue != settings.loginItemRegistered else { return }
            settings.loginItemRegistered = newValue
            save()
        }
    }
}
