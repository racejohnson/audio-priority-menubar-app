import Foundation

/// Battery levels of one Bluetooth device. The case is left out on purpose:
/// macOS reports it only while a bud sits in it.
public struct Battery: Equatable, Sendable {
    public var left: Int?
    public var right: Int?
    /// Devices with one battery, such as headphones.
    public var main: Int?

    public init(left: Int? = nil, right: Int? = nil, main: Int? = nil) {
        self.left = left
        self.right = right
        self.main = main
    }

    /// `L 80% R 81%`, one side alone while the other is in its case, or `80%`.
    public var text: String? {
        let sides = [left.map { "L \($0)%" }, right.map { "R \($0)%" }].compactMap(\.self)
        if !sides.isEmpty { return sides.joined(separator: " ") }
        return main.map { "\($0)%" }
    }

    /// The level the battery mark shows: the lower bud, or the single battery.
    public var lowest: Int? {
        [left, right].compactMap(\.self).min() ?? main
    }
}

public struct BluetoothDevice: Equatable, Sendable {
    public var name: String
    /// Uppercase hex digits only.
    public var address: String
    public var isConnected: Bool
    public var battery: Battery?
    public var productID: Int?

    public init(name: String, address: String, isConnected: Bool, battery: Battery? = nil, productID: Int? = nil) {
        self.name = name
        self.address = address
        self.isConnected = isConnected
        self.battery = battery
        self.productID = productID
    }
}

/// Reads `system_profiler -json SPBluetoothDataType`, which needs no
/// Bluetooth permission.
public enum BluetoothReport {
    /// Nil when `data` is not a report at all, so a failed run is not taken
    /// for "no Bluetooth devices".
    public static func parse(_ data: Data) -> [String: BluetoothDevice]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        var devices: [String: BluetoothDevice] = [:]
        for controller in controllers {
            for (key, isConnected) in [("device_connected", true), ("device_not_connected", false)] {
                for entry in controller[key] as? [[String: Any]] ?? [] {
                    for (name, value) in entry {
                        guard let info = value as? [String: Any],
                              let address = (info["device_address"] as? String).flatMap(BluetoothAddress.normalized) else { continue }
                        let battery = Battery(
                            left: percent(info["device_batteryLevelLeft"]),
                            right: percent(info["device_batteryLevelRight"]),
                            main: percent(info["device_batteryLevelMain"])
                        )
                        devices[address] = BluetoothDevice(
                            name: name, address: address, isConnected: isConnected,
                            battery: battery.text == nil ? nil : battery,
                            productID: (info["device_productID"] as? String).flatMap(hex)
                        )
                    }
                }
            }
        }
        return devices
    }

    private static func percent(_ value: Any?) -> Int? {
        (value as? String).flatMap { Int($0.filter(\.isNumber)) }
    }

    private static func hex(_ text: String) -> Int? {
        Int(text.replacingOccurrences(of: "0x", with: "", options: .caseInsensitive), radix: 16)
    }
}
