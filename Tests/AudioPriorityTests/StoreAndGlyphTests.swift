import Foundation
import Testing
@testable import AudioPriorityCore

private func device(_ role: Role, _ uid: String, _ name: String, _ category: DeviceCategory, transport: Transport = .usb) -> AudioDevice {
    AudioDevice(id: DeviceID(role, uid), name: name, transport: transport, category: category)
}

@MainActor
@Suite struct PriorityStoreTests {
    private let suite = "audio-priority-tests-\(UUID().uuidString)"
    private var defaults: UserDefaults { UserDefaults(suiteName: suite)! }
    private let airpods = device(.output, "airpods", "Race’s AirPods 4", .headphones, transport: .bluetooth)
    private let speakers = device(.output, "speakers", "MacBook Pro Speakers", .speakers, transport: .builtIn)
    private let display = device(.output, "display", "Studio Display Speakers", .speakers, transport: .thunderbolt)
    private let dji = device(.input, "dji", "Wireless Mic Rx", .microphones)
    private let macMic = device(.input, "mac-mic", "MacBook Pro Microphone", .microphones, transport: .builtIn)

    private func store() -> PriorityStore {
        let store = PriorityStore(defaults: defaults)
        store.register([speakers, airpods, display, dji, macMic])
        return store
    }

    private func uids(_ store: PriorityStore, _ role: Role) -> [String] {
        store.devices(for: role, connected: []).map(\.uid)
    }

    @Test func headphonesRankAboveSpeakers() {
        let store = store()
        #expect(uids(store, .output) == ["airpods", "speakers", "display"])
        #expect(uids(store, .input) == ["dji", "mac-mic"])
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func settingsSurviveARelaunch() {
        let first = store()
        first.move(DeviceID(.output, "display"), toVisibleIndex: 0)
        first.setHidden(DeviceID(.input, "mac-mic"), true)
        first.auto = false
        let second = PriorityStore(defaults: defaults)
        #expect(uids(second, .output) == ["airpods", "display", "speakers"])
        #expect(second.isHidden(DeviceID(.input, "mac-mic")))
        #expect(second.auto == false)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func aDisconnectedDeviceIsListedFromMemory() {
        let store = store()
        let listed = store.devices(for: .output, connected: [speakers])
        #expect(listed.map(\.isConnected) == [false, true, false])
        #expect(listed[0].name == "Race’s AirPods 4")
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func aHiddenDeviceKeepsItsRank() {
        let store = store()
        store.register([device(.input, "iphone", "iPhone Microphone", .microphones)])
        store.setHidden(DeviceID(.input, "mac-mic"), true)
        // Visible order is dji, iphone. Moving iphone to the top leaves mac-mic where it was.
        store.move(DeviceID(.input, "iphone"), toVisibleIndex: 0)
        #expect(uids(store, .input) == ["iphone", "dji", "mac-mic"])
        store.move(DeviceID(.input, "iphone"), toVisibleIndex: 1)
        #expect(uids(store, .input) == ["dji", "iphone", "mac-mic"])
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test func anOutputCanMoveBetweenHeadphonesAndSpeakers() {
        let store = store()
        store.setCategory(.headphones, for: DeviceID(.output, "display"))
        #expect(uids(store, .output) == ["airpods", "display", "speakers"])
        // CoreAudio still calls it speakers; the user's choice wins.
        store.register([display])
        #expect(store.category(of: DeviceID(.output, "display")) == .headphones)
        UserDefaults().removePersistentDomain(forName: suite)
    }
}

@Suite struct GlyphAndReportTests {
    @Test func glyphs() {
        func glyph(_ name: String, _ role: Role = .output, _ category: DeviceCategory = .speakers, _ transport: Transport = .usb, productID: Int? = nil) -> GlyphKey {
            DeviceGlyph.glyph(for: AudioDevice(id: DeviceID(role, "x"), name: name, transport: transport, category: category, productID: productID))
        }
        #expect(glyph("Wireless Mic Rx", .input, .microphones) == .djiMicMini)
        #expect(glyph("Race’s AirPods 4", .output, .headphones, .bluetooth) == .symbol("airpods.gen4"))
        #expect(glyph("Buds", .output, .headphones, .bluetooth, productID: 0x201B) == .symbol("airpods.gen4"))
        #expect(glyph("Someone’s AirPods Pro", .output, .headphones, .bluetooth) == .symbol("airpods.pro"))
        #expect(glyph("MacBook Pro Speakers", .output, .speakers, .builtIn) == .symbol("laptopcomputer"))
        #expect(glyph("MacBook Pro Microphone", .input, .microphones, .builtIn) == .symbol("laptopcomputer"))
        #expect(glyph("Race’s iPhone 17 Pro Microphone", .input, .microphones, .continuity) == .symbol("iphone"))
        #expect(glyph("Studio Display Speakers", .output, .speakers, .thunderbolt) == .symbol("display"))
        #expect(glyph("Scarlett 2i2", .input, .microphones) == .symbol("mic"))
        #expect(glyph("WH-1000XM5", .output, .headphones, .bluetooth) == .symbol("headphones"))
    }

    @Test func headphoneNames() {
        #expect(HeadphoneDetection.isHeadphone("Race’s AirPods 4"))
        #expect(HeadphoneDetection.isHeadphone("External Headphones"))
        #expect(!HeadphoneDetection.isHeadphone("MacBook Pro Speakers"))
        #expect(!HeadphoneDetection.isHeadphone("Jabra Speak 510"))
    }

    @Test func bluetoothAddresses() {
        #expect(BluetoothAddress.normalized("20:f4:d4:5e:f3:39") == "20F4D45EF339")
        #expect(BluetoothAddress.normalized("20-F4-D4-5E-F3-39:output") == "20F4D45EF339")
        #expect(BluetoothAddress.normalized("BuiltInSpeakerDevice") == nil)
        #expect(BluetoothAddress.dashed("20F4D45EF339") == "20-F4-D4-5E-F3-39")
    }

    @Test func batteryText() {
        #expect(Battery(left: 80, right: 81).text == "L 80% R 81%")
        #expect(Battery(left: 80).text == "L 80%")
        #expect(Battery(main: 64).text == "64%")
        #expect(Battery().text == nil)
        #expect(Battery(left: 80, right: 12).lowest == 12)
    }

    @Test func parsesTheSystemReport() throws {
        let json = """
        {"SPBluetoothDataType":[{"device_connected":[{"Race’s AirPods 4":{"device_address":"20:F4:D4:5E:F3:39",
        "device_batteryLevelLeft":"78%","device_batteryLevelRight":"80%","device_productID":"0x201B","device_minorType":"Headphones"}}],
        "device_not_connected":[{"Old Speaker":{"device_address":"AA:BB:CC:DD:EE:FF"}}]}]}
        """
        let report = BluetoothReport.parse(Data(json.utf8))
        let airpods = try #require(report["20F4D45EF339"])
        #expect(airpods.isConnected)
        #expect(airpods.battery == Battery(left: 78, right: 80))
        #expect(airpods.productID == 0x201B)
        #expect(report["AABBCCDDEEFF"]?.isConnected == false)
        #expect(report["AABBCCDDEEFF"]?.battery == nil)
    }
}
