import AppKit
import AudioPriorityCore
import Observation

/// What the panel and the menu-bar capsule show, and what the user can do.
/// It reads the Mac through `AudioSystem`, asks `SwitchEngine` what should
/// change, and makes the switches.
@Observable
@MainActor
final class AppModel {
    /// Every remembered device per role in rank order, hidden ones included.
    private(set) var devices: [Role: [AudioDevice]] = [:]
    /// The UID of the Mac's default device per role.
    private(set) var current: [Role: String] = [:]
    /// Nil where the device in use has no volume control.
    private(set) var volume: [Role: Float] = [:]
    private(set) var auto: Bool
    private(set) var bluetooth: [String: BluetoothDevice] = [:]
    /// Bluetooth addresses being connected or disconnected right now.
    private(set) var connecting: Set<String> = []
    /// The device macOS keeps moving a role to, which is being left alone.
    private(set) var takeover: [Role: String] = [:]
    var showsHidden = false
    let launchAtLogin: LaunchAtLogin
    let isDryRun: Bool

    @ObservationIgnored private let store: PriorityStore
    @ObservationIgnored private let audio: AudioSystem
    @ObservationIgnored private var engine: SwitchEngine
    @ObservationIgnored private var connected: [AudioDevice] = []
    @ObservationIgnored private var refreshIsScheduled = false
    @ObservationIgnored private var pauseTimer: Task<Void, Never>?
    @ObservationIgnored private var batteryTimer: Task<Void, Never>?
    /// A paired device the user clicked while it was off: use it once it connects.
    @ObservationIgnored private var selectOnArrival: DeviceID?
    /// Apple silicon models are all "MacNN,N", so a built-in battery is what tells a laptop apart.
    private static let hostIsLaptop = hasBuiltInBattery()

    init(isDryRun: Bool) {
        self.isDryRun = isDryRun
        // A dry run keeps its own, throwaway settings so the real ones are never touched.
        let defaults: UserDefaults
        if isDryRun {
            let suite = "com.racejohnson.audio-priority.dry-run"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }
        store = PriorityStore(defaults: defaults)
        audio = AudioSystem(isDryRun: isDryRun)
        engine = SwitchEngine(auto: store.auto)
        auto = store.auto
        launchAtLogin = LaunchAtLogin(store: store, isDryRun: isDryRun)
    }

    func start() {
        audio.onChange = { [weak self] in self?.scheduleRefresh() }
        audio.onVolumeChange = { [weak self] in self?.readVolume() }
        audio.start()
        refresh()
        launchAtLogin.sync()
        refreshBluetooth()
    }

    // MARK: What the views read

    func isHidden(_ device: AudioDevice) -> Bool { store.isHidden(device.id) }

    func visibleDevices(_ category: DeviceCategory) -> [AudioDevice] {
        (devices[category.role] ?? []).filter { $0.category == category && !isHidden($0) }
    }

    func hiddenDevices(_ role: Role) -> [AudioDevice] {
        (devices[role] ?? []).filter(isHidden)
    }

    var hiddenCount: Int { Role.allCases.reduce(0) { $0 + hiddenDevices($1).count } }

    func connectedCount(_ role: Role) -> Int {
        (devices[role] ?? []).count { $0.isConnected && !isHidden($0) }
    }

    func currentDevice(_ role: Role) -> AudioDevice? {
        (devices[role] ?? []).first { $0.uid == current[role] && $0.isConnected }
    }

    func isCurrent(_ device: AudioDevice) -> Bool {
        device.isConnected && current[device.role] == device.uid
    }

    func glyph(for device: AudioDevice) -> GlyphKey {
        DeviceGlyph.glyph(for: device, hostIsLaptop: Self.hostIsLaptop)
    }

    func battery(for device: AudioDevice) -> Battery? {
        device.bluetoothAddress.flatMap { bluetooth[$0]?.battery }
    }

    func isConnecting(_ device: AudioDevice) -> Bool {
        device.bluetoothAddress.map(connecting.contains) ?? false
    }

    /// Whether a disconnected device can be connected from here.
    func canConnect(_ device: AudioDevice) -> Bool {
        !device.isConnected && device.transport == .bluetooth && device.bluetoothAddress != nil
    }

    func detail(for device: AudioDevice) -> String {
        if isHidden(device) { return device.isConnected ? "Hidden" : "Hidden · not connected" }
        if isConnecting(device) { return device.isConnected ? "Disconnecting…" : "Connecting…" }
        if !device.isConnected { return canConnect(device) ? "Paired · not connected" : "Not connected" }
        return DeviceGlyph.detail(for: device)
    }

    /// What the takeover banner says, if macOS is being left to have its way.
    var takeoverNote: String? {
        if let name = takeoverName(.output) { return "macOS keeps moving the output to \(name), so it was left there." }
        if let name = takeoverName(.input) { return "Another app keeps taking the microphone to \(name). Trying again in 30 seconds." }
        return nil
    }

    private func takeoverName(_ role: Role) -> String? {
        guard let uid = takeover[role], current[role] == uid else { return nil }
        return (devices[role] ?? []).first { $0.uid == uid }?.name
    }

    // MARK: What the user can do

    func select(_ device: AudioDevice) {
        if device.isConnected {
            run(.userSelected(device.role, device.uid))
        } else if canConnect(device) {
            selectOnArrival = device.id
            setConnected(true, device)
        }
    }

    func setConnected(_ connect: Bool, _ device: AudioDevice) {
        guard let address = device.bluetoothAddress, !connecting.contains(address) else { return }
        guard !isDryRun else {
            log("dry run: would \(connect ? "connect" : "disconnect") \(device.name)")
            return
        }
        connecting.insert(address)
        Task {
            _ = await Bluetooth.setConnected(connect, address: address)
            connecting.remove(address)
            if selectOnArrival?.uid == device.uid, !connect { selectOnArrival = nil }
            scheduleRefresh()
            refreshBluetooth(after: .seconds(2))
        }
    }

    func setAuto(_ on: Bool) {
        store.auto = on
        auto = on
        run(.autoChanged(on))
    }

    func setHidden(_ hidden: Bool, _ device: AudioDevice) {
        store.setHidden(device.id, hidden)
        if hiddenCount == 0 { showsHidden = false }
        rebuild()
        run(.prioritiesChanged(device.role))
    }

    /// Moves a device to `index` among the visible devices of its list.
    func move(_ device: AudioDevice, toVisibleIndex index: Int) {
        store.move(device.id, toVisibleIndex: index)
        rebuild()
        run(.prioritiesChanged(device.role))
    }

    func canMove(_ device: AudioDevice, by offset: Int) -> Bool {
        let list = visibleDevices(device.category)
        guard let index = list.firstIndex(of: device) else { return false }
        return list.indices.contains(index + offset)
    }

    func move(_ device: AudioDevice, by offset: Int) {
        guard canMove(device, by: offset), let index = visibleDevices(device.category).firstIndex(of: device) else { return }
        move(device, toVisibleIndex: index + offset)
    }

    /// Moves an output between Headphones and Speakers.
    func setCategory(_ category: DeviceCategory, _ device: AudioDevice) {
        store.setCategory(category, for: device.id)
        rebuild()
        run(.prioritiesChanged(device.role))
    }

    func setVolume(_ value: Float, _ role: Role) {
        guard let device = currentDevice(role) else { return }
        volume[role] = value
        audio.setVolume(value, for: device.id)
    }

    func panelDidOpen() {
        readVolume()
        refreshBluetooth()
        // Battery levels drift while the panel is open.
        batteryTimer?.cancel()
        batteryTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.refreshBluetooth()
            }
        }
    }

    func panelDidClose() {
        batteryTimer?.cancel()
        batteryTimer = nil
    }

    // MARK: Following the Mac

    /// CoreAudio reports a device connecting as several changes in a row.
    /// Waiting a moment lets them be seen together, so a default that macOS
    /// moved because a device arrived is recognised as that.
    private func scheduleRefresh() {
        guard !refreshIsScheduled else { return }
        refreshIsScheduled = true
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            refreshIsScheduled = false
            refresh()
        }
    }

    private func refresh() {
        connected = audio.devices().map { device in
            var device = device
            device.productID = device.bluetoothAddress.flatMap { bluetooth[$0]?.productID }
            return device
        }
        readCurrent()
        if store.isEmpty {
            // First launch: the devices in use now go to the top of their
            // lists, so starting the app changes as little as possible.
            let inUse = connected.filter { current[$0.role] == $0.uid }
            store.register(inUse + connected.filter { !inUse.contains($0) })
        } else {
            store.register(connected)
        }
        rebuild()
        run(.systemChanged)
        if let wanted = selectOnArrival, let device = (devices[wanted.role] ?? []).first(where: { $0.id == wanted && $0.isConnected }) {
            selectOnArrival = nil
            run(.userSelected(device.role, device.uid))
        }
    }

    private func readCurrent() {
        for role in Role.allCases { current[role] = audio.defaultDevice(role) }
    }

    private func rebuild() {
        for role in Role.allCases { devices[role] = store.devices(for: role, connected: connected) }
        audio.watchVolume(of: Role.allCases.compactMap { currentDevice($0)?.id })
        readVolume()
    }

    private func readVolume() {
        for role in Role.allCases { volume[role] = currentDevice(role).flatMap { audio.volume($0.id) } }
    }

    private func run(_ event: SwitchEngine.Event) {
        let input = SwitchEngine.Input(
            ranking: Dictionary(uniqueKeysWithValues: Role.allCases.map { role in
                (role, (devices[role] ?? []).filter { $0.isConnected && !isHidden($0) }.map(\.uid))
            }),
            connected: Dictionary(uniqueKeysWithValues: Role.allCases.map { role in
                (role, Set(connected.filter { $0.role == role }.map(\.uid)))
            }),
            current: current,
            now: ProcessInfo.processInfo.systemUptime,
            userPicking: event == .systemChanged && SystemSoundPicker.isInUse
        )
        for command in engine.handle(event, input) {
            let id = DeviceID(command.role, command.uid)
            let name = connected.first { $0.id == id }?.name ?? command.uid
            if isDryRun {
                log("dry run: would switch \(command.role.rawValue) to \(name)")
            } else if audio.setDefault(id) {
                log("switched \(command.role.rawValue) to \(name)")
            } else {
                log("could not switch \(command.role.rawValue) to \(name)")
            }
        }
        readCurrent()
        takeover = engine.takeover
        audio.watchVolume(of: Role.allCases.compactMap { currentDevice($0)?.id })
        readVolume()
        schedulePauseEnd()
    }

    private func schedulePauseEnd() {
        pauseTimer?.cancel()
        pauseTimer = nil
        guard let end = engine.microphonePauseEndsAt else { return }
        let wait = max(end - ProcessInfo.processInfo.systemUptime, 0)
        pauseTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.run(.microphonePauseEnded)
        }
    }

    private func refreshBluetooth(after delay: Duration = .zero) {
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            await loadBluetooth()
        }
    }

    /// Reads the paired devices and their battery levels (about a second).
    func loadBluetooth() async {
        let report = await Bluetooth.report()
        guard report != bluetooth else { return }
        let products = { (devices: [String: BluetoothDevice]) in devices.compactMapValues(\.productID) }
        let isNewProduct = products(report) != products(bluetooth)
        bluetooth = report
        // A product ID seen for the first time can change a device's glyph.
        if isNewProduct { refresh() }
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("Audio Priority: \(message)\n".utf8))
    }
}

/// True when the Mac has a built-in battery, which only a laptop does.
private func hasBuiltInBattery() -> Bool {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    defer { if service != 0 { IOObjectRelease(service) } }
    return service != 0
}
