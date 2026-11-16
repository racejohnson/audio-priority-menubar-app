import Foundation

/// The glyph a device is drawn with: a system symbol wherever one exists, and
/// one custom drawing for the DJI Mic Mini.
public enum GlyphKey: Hashable, Sendable {
    case symbol(String)
    case djiMicMini
}

public enum DeviceGlyph {
    /// Apple's Bluetooth product IDs for AirPods, where the name alone (which
    /// the owner can change) would not say which model it is.
    private static let airPodsSymbols: [Int: String] = [
        0x2002: "airpods", 0x200F: "airpods",
        0x2013: "airpods.gen3",
        0x2019: "airpods.gen4", 0x201B: "airpods.gen4",
        0x200E: "airpods.pro", 0x2014: "airpods.pro", 0x2024: "airpods.pro",
        0x200A: "airpods.max", 0x201F: "airpods.max",
    ]

    public static func isDJIMic(_ name: String) -> Bool {
        let name = name.lowercased()
        return name == "wireless mic rx" || name.contains("dji mic")
    }

    public static func glyph(for device: AudioDevice, hostIsLaptop: Bool = true) -> GlyphKey {
        let name = device.name.lowercased()
        if isDJIMic(name) { return .djiMicMini }
        if let productID = device.productID, let symbol = airPodsSymbols[productID] { return .symbol(symbol) }
        if name.contains("airpods max") { return .symbol("airpods.max") }
        if name.contains("airpods pro") { return .symbol("airpods.pro") }
        if name.contains("airpods 4") { return .symbol("airpods.gen4") }
        if name.contains("airpods 3") { return .symbol("airpods.gen3") }
        if name.contains("airpods") { return .symbol("airpods") }
        if name.contains("beats") { return .symbol("beats.headphones") }
        if name.contains("homepod") { return .symbol("homepod.fill") }
        if name.contains("iphone") { return .symbol("iphone") }
        if name.contains("ipad") { return .symbol("ipad") }
        // A display's speakers and microphone, whatever they are wired through.
        if name.contains("display") { return .symbol("display") }
        switch device.transport {
        case .builtIn: return .symbol(hostIsLaptop ? "laptopcomputer" : "desktopcomputer")
        case .displayPort: return .symbol("display")
        case .hdmi: return .symbol("tv")
        case .airPlay: return .symbol("airplayaudio")
        default: break
        }
        switch device.category {
        case .headphones: return .symbol("headphones")
        case .microphones: return .symbol("mic")
        case .speakers: return .symbol(device.transport == .virtual ? "speaker.wave.2.fill" : "hifispeaker.fill")
        }
    }

    /// The second line of a connected device's row. `transmitter` is what a
    /// wireless microphone's receiver says about its microphone, when known.
    public static func detail(for device: AudioDevice, transmitter: TransmitterStatus? = nil) -> String {
        guard isDJIMic(device.name) else { return device.transport.label }
        let name = "DJI Mic Mini"
        guard let transmitter else { return "\(name) · \(device.transport.label)" }
        if !transmitter.isLinked { return "\(name) · Mic off" }
        if transmitter.isCharging { return "\(name) · Charging" }
        if transmitter.isLow { return "\(name) · Low battery" }
        // With a battery mark beside it, the name is enough.
        return transmitter.gauge == nil ? "\(name) · \(device.transport.label)" : name
    }
}

/// Decides whether an output is headphones when the device does not say so
/// itself. The keyword list is from Audio Priority Bar by Camille Guillory,
/// which continues AudioPriorityBar by Tobias Lütke (both GPL-3.0).
public enum HeadphoneDetection {
    private static let keywords = [
        "headphone", "headset", "earphone", "earbud", "earbuds", "buds", "pods",
        "airpods", "earpods", "beats", "powerbeats", "beatsx", "beats fit",
        "beats solo", "beats studio", "wh-1000", "wf-1000", "linkbuds", "inzone",
        "galaxy buds", "buds pro", "buds live", "buds fe", "quietcomfort",
        "qc ultra", "qc45", "qc35", "soundsport", "sport earbuds", "momentum",
        "hd 4", "hd 5", "pxc", "jabra", "elite", "evolve", "jbl tune",
        "jbl live", "jbl tour", "jbl reflect", "anker", "soundcore",
        "skullcandy", "nothing ear", "oneplus buds", "pixel buds",
        "huawei freebuds", "oppo enco", "technics eah", "bowers", "b&w px",
        "denon perl", "focal bathys", "hifiman", "shure aonic",
        "audio-technica ath", "beyerdynamic", "marshall", "bang & olufsen",
        "b&o", "akg", "plantronics", "poly", "razer", "steelseries", "hyperx",
        "logitech g pro", "astro", "corsair", "1more", "tozo", "edifier",
        "fiio", "moondrop",
    ]
    private static let speakerProducts = ["jabra speak", "homepod"]

    public static func isHeadphone(_ name: String) -> Bool {
        let name = name.lowercased()
        guard !speakerProducts.contains(where: name.contains) else { return false }
        return keywords.contains(where: name.contains)
    }
}
