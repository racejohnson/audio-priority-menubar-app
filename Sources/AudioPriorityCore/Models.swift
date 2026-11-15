import Foundation

public enum Role: String, Codable, Sendable, CaseIterable {
    case output, input
}

/// The three ranked lists. Headphones always rank above speakers.
public enum DeviceCategory: String, Codable, Sendable, CaseIterable {
    case headphones, speakers, microphones

    public var role: Role { self == .microphones ? .input : .output }

    public static func categories(for role: Role) -> [DeviceCategory] {
        role == .output ? [.headphones, .speakers] : [.microphones]
    }
}

public enum Transport: String, Codable, Sendable {
    case builtIn, bluetooth, usb, thunderbolt, displayPort, hdmi, continuity, airPlay, virtual, other

    public var label: String {
        switch self {
        case .builtIn: "Built-in"
        case .bluetooth: "Bluetooth"
        case .usb: "USB"
        case .thunderbolt: "Thunderbolt"
        case .displayPort: "DisplayPort"
        case .hdmi: "HDMI"
        case .continuity: "Continuity"
        case .airPlay: "AirPlay"
        case .virtual: "Virtual"
        case .other: "Audio device"
        }
    }
}

/// One side of a device. CoreAudio gives a headset one UID for both its
/// speaker and its microphone, so the role is part of the identity.
public struct DeviceID: Hashable, Codable, Sendable {
    public var role: Role
    public var uid: String

    public init(_ role: Role, _ uid: String) {
        self.role = role
        self.uid = uid
    }

    /// The form used as a key in saved settings.
    public var key: String { "\(role.rawValue)|\(uid)" }
}

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: DeviceID
    public var name: String
    public var transport: Transport
    /// Headphones or speakers for an output, as far as the device itself says.
    /// The user's own choice, kept by `PriorityStore`, overrides it.
    public var category: DeviceCategory
    public var isConnected: Bool
    /// Uppercase hex digits only, e.g. `20F4D45EF339`.
    public var bluetoothAddress: String?
    public var productID: Int?

    public init(
        id: DeviceID,
        name: String,
        transport: Transport,
        category: DeviceCategory,
        isConnected: Bool = true,
        bluetoothAddress: String? = nil,
        productID: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.transport = transport
        self.category = category
        self.isConnected = isConnected
        self.bluetoothAddress = bluetoothAddress
        self.productID = productID
    }

    public var role: Role { id.role }
    public var uid: String { id.uid }
}

/// What a remembered device needs to be listed while it is disconnected.
public struct KnownDevice: Codable, Equatable, Sendable {
    public var name: String
    public var transport: Transport
    public var category: DeviceCategory
    public var bluetoothAddress: String?
    public var productID: Int?
}

public enum BluetoothAddress {
    /// `20:f4:d4:5e:f3:39` and `20-F4-D4-5E-F3-39:output` both become `20F4D45EF339`.
    public static func normalized(_ text: String) -> String? {
        let head = text.split(separator: ":", omittingEmptySubsequences: false)
        // A CoreAudio Bluetooth UID is the address with dashes, then `:input` or `:output`.
        let candidate = text.contains("-") ? String(head.first ?? "") : text
        let hex = candidate.uppercased().filter(\.isHexDigit)
        return hex.count == 12 ? hex : nil
    }

    /// The `20-F4-D4-5E-F3-39` form IOBluetooth takes.
    public static func dashed(_ normalized: String) -> String {
        stride(from: 0, to: normalized.count, by: 2).map { offset -> String in
            let start = normalized.index(normalized.startIndex, offsetBy: offset)
            return String(normalized[start..<normalized.index(start, offsetBy: 2)])
        }.joined(separator: "-")
    }
}
