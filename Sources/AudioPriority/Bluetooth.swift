import AppKit
import AudioPriorityCore
import IOBluetooth

enum Bluetooth {
    /// Connects or disconnects a paired device. IOBluetooth blocks for
    /// seconds, so the call runs off the main thread.
    static func setConnected(_ connected: Bool, address: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let device = IOBluetoothDevice(addressString: BluetoothAddress.dashed(address)) else {
                    continuation.resume(returning: false)
                    return
                }
                let result = connected ? device.openConnection() : device.closeConnection()
                continuation.resume(returning: result == kIOReturnSuccess)
            }
        }
    }

    /// Paired devices with their battery levels, from `system_profiler`,
    /// which needs no Bluetooth permission. Takes about a second. Nil when
    /// the tool failed, so the last good report can be kept.
    static func report() async -> [String: BluetoothDevice]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["-json", "SPBluetoothDataType"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    // It normally takes a second. If it hangs, end it, so this is not left waiting for good.
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
                        if process.isRunning { process.terminate() }
                    }
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0 ? BluetoothReport.parse(data) : nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// Whether the user has Control Center or Sound settings open, in which case a
/// change of default device is their own pick and not macOS moving it.
/// From Audio Priority Bar by Camille Guillory, which continues
/// AudioPriorityBar by Tobias Lütke (both GPL-3.0).
@MainActor
enum SystemSoundPicker {
    static var isInUse: Bool {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.systempreferences" { return true }
        let controlCenter = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").map(\.processIdentifier))
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        // Control Center always owns its menu-bar items; anything else of its on screen is an open module.
        let menuBarLayer = Int(CGWindowLevelForKey(.statusWindow))
        return windows.contains {
            controlCenter.contains($0[kCGWindowOwnerPID as String] as? pid_t ?? -1)
                && ($0[kCGWindowLayer as String] as? Int) != menuBarLayer
        }
    }
}
