import AppKit
import AudioPriorityCore

/// `--readme <folder>`: the README's pictures, drawn from a made-up Mac so
/// they come out the same whatever is plugged in. Dry run only.
@MainActor
enum ReadmePictures {
    private struct Shot {
        var panel: CGImage
        var size: CGSize
        var capsule: NSImage
        var isDark: Bool
    }

    static func write(model: AppModel, to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let address = "A1B2C3D4E5F6", uid = "A1-B2-C3-D4-E5-F6"
        let airPods = [
            AudioDevice(id: DeviceID(.output, "\(uid):output"), name: "Race’s AirPods 4", transport: .bluetooth, category: .headphones, bluetoothAddress: address),
            AudioDevice(id: DeviceID(.input, "\(uid):input"), name: "Race’s AirPods 4", transport: .bluetooth, category: .microphones, bluetoothAddress: address),
        ]
        let others = [
            AudioDevice(id: DeviceID(.output, "speakers"), name: "MacBook Pro Speakers", transport: .builtIn, category: .speakers),
            AudioDevice(id: DeviceID(.input, "dji"), name: "Wireless Mic Rx", transport: .usb, category: .microphones),
            AudioDevice(id: DeviceID(.input, "mac-mic"), name: "MacBook Pro Microphone", transport: .builtIn, category: .microphones),
            AudioDevice(id: DeviceID(.input, "iphone"), name: "Race’s iPhone 17 Pro Microphone", transport: .continuity, category: .microphones),
        ]
        func bluetooth(connected: Bool) -> [String: BluetoothDevice] {
            [address: BluetoothDevice(
                name: "Race’s AirPods 4", address: address, isConnected: connected,
                battery: connected ? Battery(left: 80, right: 81) : nil, productID: 0x201B
            )]
        }
        let withAirPods = AppModel.Demo(
            connected: airPods + others, current: [.output: "\(uid):output", .input: "dji"],
            volume: [.output: 0.55, .input: 0.8], bluetooth: bluetooth(connected: true)
        )
        var shots: [Shot] = []
        func shoot(dark: Bool) {
            guard let rep = Snapshot.render(model, dark: dark), let image = rep.cgImage else { return }
            let face = StatusItemController.face(of: model)
            shots.append(Shot(
                panel: image, size: rep.size,
                capsule: Glyphs.capsule(output: face.output, input: face.input, isManual: face.isManual), isDark: dark
            ))
        }

        // 1. AirPods in, the DJI microphone held.
        model.show(withAirPods)
        shoot(dark: false)
        save(chip(shots[0].capsule), to: folder.appendingPathComponent("capsule-auto.png"))

        // 2. The AirPods are away: the speakers take over and the AirPods wait, paired.
        model.show(AppModel.Demo(
            connected: others, current: [.output: "speakers", .input: "dji"],
            volume: [.output: 0.4, .input: 0.8], bluetooth: bluetooth(connected: false)
        ))
        shoot(dark: false)

        // 3. Auto Switch off, with a device hidden.
        model.show(withAirPods)
        model.setAuto(false)
        if let phone = (model.devices[.input] ?? []).first(where: { $0.uid == "iphone" }) { model.setHidden(true, phone) }
        shoot(dark: true)
        save(chip(shots[2].capsule), to: folder.appendingPathComponent("capsule-manual.png"))

        save(hero(shots), to: folder.appendingPathComponent("panel.png"))
        print("Wrote the README's pictures to \(folder.path)")
        NSApp.terminate(nil)
    }

    /// The three panels side by side, each under a strip of menu bar with its capsule.
    private static func hero(_ shots: [Shot]) -> NSImage {
        let panelWidth: CGFloat = 312, gap: CGFloat = 44, margin: CGFloat = 40
        let barHeight: CGFloat = 30, barGap: CGFloat = 7, radius: CGFloat = 22
        let tallest = shots.map(\.size.height).max() ?? 0
        let width = margin * 2 + CGFloat(shots.count) * panelWidth + CGFloat(shots.count - 1) * gap
        let height = margin * 0.6 + barHeight + barGap + tallest + margin * 1.4
        return Bitmap.draw(width: width, height: height, scales: [2]) { context in
            for (index, shot) in shots.enumerated() {
                let left = margin + CGFloat(index) * (panelWidth + gap)
                let top = height - margin * 0.6

                // The menu bar: black, fading out to either side, with the item pressed.
                let bar = CGRect(x: left - 6, y: top - barHeight, width: panelWidth + 12, height: barHeight)
                context.saveGState()
                context.clip(to: bar)
                let fade = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [0, 1, 1, 0].map { CGColor(gray: 0, alpha: $0) } as CFArray, locations: [0, 0.3, 0.7, 1]
                )
                if let fade {
                    context.drawLinearGradient(fade, start: CGPoint(x: bar.minX, y: 0), end: CGPoint(x: bar.maxX, y: 0), options: [])
                }
                context.restoreGState()
                let capsule = shot.capsule.size
                let pressed = CGRect(x: bar.midX - capsule.width / 2 - 6, y: bar.midY - 12, width: capsule.width + 12, height: 24)
                context.setFillColor(CGColor(gray: 1, alpha: 0.18))
                context.addPath(CGPath(roundedRect: pressed, cornerWidth: 7, cornerHeight: 7, transform: nil))
                context.fillPath()
                drawWhite(shot.capsule, at: CGPoint(x: bar.midX - capsule.width / 2, y: bar.midY - capsule.height / 2), in: context)

                // The panel: rounded, with its shadow and a hairline edge.
                let frame = CGRect(x: left, y: bar.minY - barGap - shot.size.height, width: panelWidth, height: shot.size.height)
                let shape = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(gray: 0, alpha: 0.22))
                context.setFillColor(Snapshot.backdrop(dark: shot.isDark).cgColor)
                context.addPath(shape)
                context.fillPath()
                context.restoreGState()
                context.saveGState()
                context.addPath(shape)
                context.clip()
                context.draw(shot.panel, in: frame)
                context.restoreGState()
                context.setStrokeColor(CGColor(gray: shot.isDark ? 1 : 0, alpha: shot.isDark ? 0.16 : 0.12))
                context.setLineWidth(0.5)
                context.addPath(CGPath(roundedRect: frame.insetBy(dx: 0.25, dy: 0.25), cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.strokePath()
            }
        }
    }

    /// One capsule on a piece of menu bar, to sit in a line of text.
    private static func chip(_ capsule: NSImage) -> NSImage {
        let size = CGSize(width: capsule.size.width + 16, height: 30)
        return Bitmap.draw(width: size.width, height: size.height, scales: [2]) { context in
            context.setFillColor(.black)
            context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 7, cornerHeight: 7, transform: nil))
            context.fillPath()
            drawWhite(capsule, at: CGPoint(x: 8, y: (size.height - capsule.size.height) / 2), in: context)
        }
    }

    /// A template image is one ink: draw it, then tint what was drawn.
    private static func drawWhite(_ image: NSImage, at origin: CGPoint, in context: CGContext) {
        let rect = CGRect(origin: origin, size: image.size)
        context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
        image.draw(in: rect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.endTransparencyLayer()
        context.setBlendMode(.normal)
    }

    private static func save(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return }
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
