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
    /// What each wireless microphone's receiver says about its transmitter, by device UID.
    private(set) var transmitters: [String: TransmitterStatus] = [:]
    /// Bluetooth addresses being connected or disconnected right now.
    private(set) var connecting: Set<String> = []
    /// Bluetooth addresses whose last connect or disconnect just failed.
    private(set) var failedToConnect: Set<String> = []
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
    /// After this the click is too old to act on: a device that connects
    /// later did so for some other reason.
    @ObservationIgnored private var selectOnArrivalEnds: TimeInterval = 0
    @ObservationIgnored private var demo: Demo?
    /// Listens to a DJI receiver while one is plugged in.
    @ObservationIgnored private lazy var djiReceiver = DJIReceiver { [weak self] status in self?.transmitterChanged(status) }
    /// The UID of the DJI receiver's microphone, while it is plugged in.
    @ObservationIgnored private var djiMicrophoneUID: String?
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

    /// A made-up Mac for the README's pictures, so they do not depend on
    /// what happens to be plugged in.
    struct Demo {
        var connected: [AudioDevice]
        var current: [Role: String]
        var volume: [Role: Float]
        var bluetooth: [String: BluetoothDevice]
        var transmitters: [String: TransmitterStatus] = [:]
    }

    /// Shows `demo` in place of the real devices. Dry run only, and in place
    /// of `start()`: nothing real is read or listened to afterwards.
    func show(_ demo: Demo) {
        guard isDryRun else { return }
        self.demo = demo
        bluetooth = demo.bluetooth
        transmitters = demo.transmitters
        refresh()
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

    func transmitter(for device: AudioDevice) -> TransmitterStatus? {
        device.role == .input && device.isConnected ? transmitters[device.uid] : nil
    }

    /// The receiver is plugged in but its microphone is switched off.
    func isMicOff(_ device: AudioDevice) -> Bool {
        transmitter(for: device)?.isLinked == false
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
        if let address = device.bluetoothAddress, failedToConnect.contains(address) {
            return device.isConnected ? "Couldn’t disconnect" : "Couldn’t connect"
        }
        if !device.isConnected { return canConnect(device) ? "Paired · not connected" : "Not connected" }
        if let status = transmitter(for: device) {
            if !status.isLinked { return "DJI Mic Mini · Mic off" }
            if status.isCharging { return "DJI Mic Mini · Charging" }
            if status.isLow { return "DJI Mic Mini · Low battery" }
            if status.gauge != nil { return "DJI Mic Mini" }
        }
        return DeviceGlyph.detail(for: device)
    }

    /// What the takeover banner says, if macOS is being left to have its way.
    var takeoverNote: String? {
        if let name = takeoverName(.output) { return "macOS keeps moving the output to \(name), so it’s left there. Click a device to switch back." }
        if let name = takeoverName(.input) { return "Another app keeps taking the microphone to \(name), so it’s left there for a moment. Click a device to take it back." }
        return nil
    }

    private func takeoverName(_ role: Role) -> String? {
        guard let uid = takeover[role], current[role] == uid else { return nil }
        return (devices[role] ?? []).first { $0.uid == uid }?.name
    }

    // MARK: What the user can do

    func select(_ device: AudioDevice) {
        // A microphone that is switched off cannot be used until it is on again.
        if isMicOff(device) { return }
        if device.isConnected {
            run(.userSelected(device.role, device.uid))
        } else if canConnect(device) {
            selectOnArrival = device.id
            selectOnArrivalEnds = Self.now + 30
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
        failedToConnect.remove(address)
        Task {
            let succeeded = await Bluetooth.setConnected(connect, address: address)
            connecting.remove(address)
            if !succeeded || !connect, selectOnArrival?.uid == device.uid { selectOnArrival = nil }
            scheduleRefresh()
            refreshBluetooth(after: .seconds(2))
            if !succeeded {
                log("could not \(connect ? "connect" : "disconnect") \(device.name)")
                // Say so on the row for a few seconds.
                failedToConnect.insert(address)
                try? await Task.sleep(for: .seconds(5))
                failedToConnect.remove(address)
            }
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
        // A device that refuses the level shows the one it kept.
        if !audio.setVolume(value, for: device.id) { readVolume() }
    }

    func panelDidOpen() {
        // Approving the login item in System Settings changes what the row should say.
        if !isDryRun { launchAtLogin.refresh() }
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
        let bluetoothBefore = Set(connected.compactMap(\.bluetoothAddress))
        connected = (demo?.connected ?? audio.devices()).map { device in
            var device = device
            device.productID = device.bluetoothAddress.flatMap { bluetooth[$0]?.productID }
            return device
        }
        // A Bluetooth device that just connected: its battery level is from last time.
        if !Set(connected.compactMap(\.bluetoothAddress)).isSubset(of: bluetoothBefore) {
            refreshBluetooth(after: .seconds(3))
        }
        if demo == nil {
            djiMicrophoneUID = connected.first { $0.role == .input && DeviceGlyph.isDJIMic($0.name) }?.uid
            djiReceiver.setWanted(djiMicrophoneUID != nil)
            if djiMicrophoneUID == nil { transmitters = [:] }
        }
        readCurrent()
        let isFirstLaunch = store.isEmpty
        if isFirstLaunch {
            // First launch: the devices in use now go to the top of their
            // lists, so starting the app changes as little as possible.
            let inUse = connected.filter { current[$0.role] == $0.uid }
            store.register(inUse + connected.filter { !inUse.contains($0) })
        } else {
            store.register(connected)
        }
        rebuild()
        if isFirstLaunch {
            // Headphones rank above speakers, so a speaker in use is not at
            // the top of the output list. Keeping it as a pick leaves it be.
            for role in Role.allCases {
                if let uid = current[role] { run(.userSelected(role, uid)) }
            }
        }
        // A device the user clicked while it was off is picked before the
        // engine sees it arrive, so the engine does not first switch away.
        if let wanted = selectOnArrival {
            if Self.now > selectOnArrivalEnds {
                selectOnArrival = nil
            } else if let device = (devices[wanted.role] ?? []).first(where: { $0.id == wanted && $0.isConnected }) {
                selectOnArrival = nil
                run(.userSelected(device.role, device.uid))
            }
        }
        run(.systemChanged)
    }

    /// The DJI receiver said something new about its microphone, or went quiet (nil).
    private func transmitterChanged(_ status: TransmitterStatus?) {
        guard demo == nil else { return }
        var new: [String: TransmitterStatus] = [:]
        if let uid = djiMicrophoneUID, let status { new[uid] = status }
        guard new != transmitters else { return }
        let wasOff = transmitters.values.contains { !$0.isLinked }
        transmitters = new
        let isOff = new.values.contains { !$0.isLinked }
        guard isOff != wasOff else { return }
        log(isOff ? "the DJI microphone is switched off" : "the DJI microphone is back")
        // Its going off or coming back is a device leaving or arriving.
        run(.systemChanged)
    }

    private func readCurrent() {
        for role in Role.allCases { current[role] = demo.map { $0.current[role] } ?? audio.defaultDevice(role) }
    }

    private func rebuild() {
        for role in Role.allCases { devices[role] = store.devices(for: role, connected: connected) }
    }

    /// Seconds on a clock that keeps counting while the Mac sleeps, so a
    /// 30-second window is not stretched by a night with the lid closed.
    private static var now: TimeInterval { TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9 }

    private func readVolume() {
        for role in Role.allCases {
            volume[role] = currentDevice(role).flatMap { device in demo.map { $0.volume[role] } ?? audio.volume(device.id) }
        }
    }

    private func run(_ event: SwitchEngine.Event) {
        let input = SwitchEngine.Input(
            ranking: Dictionary(uniqueKeysWithValues: Role.allCases.map { role in
                (role, (devices[role] ?? []).filter { $0.isConnected && !isHidden($0) && !isMicOff($0) }.map(\.uid))
            }),
            connected: Dictionary(uniqueKeysWithValues: Role.allCases.map { role in
                // To the rules, a microphone that is switched off has left.
                (role, Set(connected.filter { $0.role == role && !isMicOff($0) }.map(\.uid)))
            }),
            current: current,
            now: Self.now,
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
        let wait = max(end - Self.now, 0)
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
        guard demo == nil else { return }
        // A failed read keeps the last good report.
        guard let report = await Bluetooth.report(), report != bluetooth else { return }
        let products = { (devices: [String: BluetoothDevice]) in devices.compactMapValues(\.productID) }
        let isNewProduct = products(report) != products(bluetooth)
        bluetooth = report
        // A product ID seen for the first time can change a device's glyph.
        if isNewProduct { refresh() }
    }

    private func log(_ message: String) {
        Log.write(message)
    }
}

/// True when the Mac has a built-in battery, which only a laptop does.
private func hasBuiltInBattery() -> Bool {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    defer { if service != 0 { IOObjectRelease(service) } }
    return service != 0
}
