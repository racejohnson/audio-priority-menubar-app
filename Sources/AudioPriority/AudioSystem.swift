import AudioPriorityCore
import CoreAudio
import Foundation

/// The Mac's audio devices, read and set through CoreAudio.
@MainActor
final class AudioSystem {
    /// Devices came or went, or a default device changed.
    var onChange: (@MainActor () -> Void)?
    /// The volume of a watched device changed.
    var onVolumeChange: (@MainActor () -> Void)?

    /// In a dry run nothing is ever set: switches and volume changes are only logged.
    let isDryRun: Bool
    private var deviceIDs: [String: AudioObjectID] = [:]
    private var volumeListeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var systemListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init(isDryRun: Bool) {
        self.isDryRun = isDryRun
    }

    // MARK: Reading

    /// Every device that can be the default for a role, one entry per role.
    func devices() -> [AudioDevice] {
        var found: [AudioDevice] = []
        deviceIDs = [:]
        for id in Self.array(Self.system, Self.address(kAudioHardwarePropertyDevices), of: AudioObjectID.self) {
            guard let uid = Self.string(id, Self.address(kAudioDevicePropertyDeviceUID)),
                  let name = Self.string(id, Self.address(kAudioObjectPropertyName)) else { continue }
            // Helper devices a driver marks hidden are not for picking; Sound settings skips them too.
            guard (Self.value(id, Self.address(kAudioDevicePropertyIsHidden), UInt32(0)) ?? 0) == 0 else { continue }
            let transport = Self.transport(Self.value(id, Self.address(kAudioDevicePropertyTransportType), UInt32(0)) ?? 0)
            for role in Role.allCases {
                let scope = Self.scope(role)
                let streams = Self.array(id, Self.address(kAudioDevicePropertyStreams, scope), of: AudioObjectID.self)
                let canBeDefault = Self.value(id, Self.address(kAudioDevicePropertyDeviceCanBeDefaultDevice, scope), UInt32(0)) ?? 0
                guard !streams.isEmpty, canBeDefault != 0 else { continue }
                deviceIDs[DeviceID(role, uid).key] = id
                found.append(AudioDevice(
                    id: DeviceID(role, uid), name: name, transport: transport,
                    category: role == .input ? .microphones : Self.outputCategory(name: name, transport: transport, streams: streams),
                    bluetoothAddress: transport == .bluetooth ? BluetoothAddress.normalized(uid) : nil
                ))
            }
        }
        return found
    }

    func defaultDevice(_ role: Role) -> String? {
        guard let id = Self.value(Self.system, Self.address(Self.defaultSelector(role)), AudioObjectID(0)), id != 0 else { return nil }
        return Self.string(id, Self.address(kAudioDevicePropertyDeviceUID))
    }

    /// Nil when the device has no volume control of its own.
    func volume(_ id: DeviceID) -> Float? {
        guard let (object, address) = volumeControl(id) else { return nil }
        return Self.value(object, address, Float32(0))
    }

    /// The device's volume property, if it has one that can be set.
    private func volumeControl(_ id: DeviceID) -> (AudioObjectID, AudioObjectPropertyAddress)? {
        guard let object = deviceIDs[id.key] else { return nil }
        var address = Self.address(Self.virtualMainVolume, Self.scope(id.role))
        var isSettable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address),
              AudioObjectIsPropertySettable(object, &address, &isSettable) == noErr, isSettable.boolValue else { return nil }
        return (object, address)
    }

    // MARK: Setting

    @discardableResult
    func setDefault(_ id: DeviceID) -> Bool {
        guard let object = deviceIDs[id.key] else { return false }
        guard !isDryRun else { return true }
        var address = Self.address(Self.defaultSelector(id.role))
        var value = object
        return AudioObjectSetPropertyData(Self.system, &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value) == noErr
    }

    /// False when the device did not take the new volume.
    func setVolume(_ volume: Float, for id: DeviceID) -> Bool {
        guard !isDryRun else { return true }
        guard let (object, control) = volumeControl(id) else { return false }
        var address = control
        var value = Float32(min(max(volume, 0), 1))
        return AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
    }

    // MARK: Listening

    func start() {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultInputDevice] {
            var address = Self.address(selector)
            let block = Self.listener { [weak self] in self?.onChange?() }
            AudioObjectAddPropertyListenerBlock(Self.system, &address, .main, block)
            systemListeners.append((address, block))
        }
    }

    /// Watches the volume of these devices, replacing any earlier watch.
    func watchVolume(of ids: [DeviceID]) {
        let wanted = ids.compactMap(volumeControl)
        // Most calls ask for the devices already watched.
        guard wanted.map({ [$0.0, $0.1.mScope] }) != volumeListeners.map({ [$0.0, $0.1.mScope] }) else { return }
        for (object, address, block) in volumeListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
        volumeListeners = wanted.map { object, address in
            var address = address
            let block = Self.listener { [weak self] in self?.onVolumeChange?() }
            AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
            return (object, address, block)
        }
    }

    /// CoreAudio calls its listeners on the queue it is given, outside Swift's
    /// actor checking, so the block hops to the main actor itself.
    private nonisolated static func listener(_ handler: @escaping @MainActor @Sendable () -> Void) -> AudioObjectPropertyListenerBlock {
        { _, _ in Task { @MainActor in handler() } }
    }

    // MARK: CoreAudio plumbing

    private static let system = AudioObjectID(kAudioObjectSystemObject)
    /// `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`: one volume for
    /// the whole device, whatever its channels.
    private static let virtualMainVolume: AudioObjectPropertySelector = 0x766D_7663

    private static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func scope(_ role: Role) -> AudioObjectPropertyScope {
        role == .input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
    }

    private static func defaultSelector(_ role: Role) -> AudioObjectPropertySelector {
        role == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    }

    private static func value<T: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ initial: T) -> T? {
        var address = address
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func string(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
        var address = address
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func array<T: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, of: T.Type) -> [T] {
        var address = address
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
            initialized = status == noErr ? Int(size) / MemoryLayout<T>.stride : 0
        }
    }

    private static func transport(_ type: UInt32) -> Transport {
        switch type {
        case kAudioDeviceTransportTypeBuiltIn: .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: .bluetooth
        case kAudioDeviceTransportTypeUSB: .usb
        case kAudioDeviceTransportTypeThunderbolt: .thunderbolt
        case kAudioDeviceTransportTypeDisplayPort: .displayPort
        case kAudioDeviceTransportTypeHDMI: .hdmi
        case kAudioDeviceTransportTypeAirPlay: .airPlay
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless: .continuity
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: .virtual
        default: .other
        }
    }

    /// Headphones when the device says so through its terminal type, or when
    /// its name does. macOS gives every Bluetooth output a headphones
    /// terminal, speakers included, so for Bluetooth only the name counts.
    private static func outputCategory(name: String, transport: Transport, streams: [AudioObjectID]) -> DeviceCategory {
        // 0x0302 and 0x0402 are the raw USB codes for headphones and a headset.
        let headphoneTerminals: Set<UInt32> = [kAudioStreamTerminalTypeHeadphones, 0x0302, 0x0402]
        let terminals = Set(streams.compactMap { value($0, address(kAudioStreamPropertyTerminalType), UInt32(0)) })
        if transport != .bluetooth, !terminals.isEmpty, terminals.isSubset(of: headphoneTerminals) { return .headphones }
        return HeadphoneDetection.isHeadphone(name) ? .headphones : .speakers
    }
}
