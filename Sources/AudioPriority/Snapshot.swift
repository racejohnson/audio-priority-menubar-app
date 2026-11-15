import AppKit
import AudioPriorityCore
import SwiftUI

/// `--snapshot <folder>`: pictures of the panel and the capsule drawn from the
/// Mac's real devices, without showing a window. For checking the look after
/// a change; best run as a dry run, so nothing is switched or saved.
@MainActor
enum Snapshot {
    static func write(model: AppModel, to folder: URL) {
        Task {
            await model.loadBluetooth()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            panel(model, dark: false, to: folder.appendingPathComponent("panel-light.png"))
            panel(model, dark: true, to: folder.appendingPathComponent("panel-dark.png"))
            capsules(model, to: folder.appendingPathComponent("capsule.png"))
            if model.isDryRun {
                // A second state, safe only because a dry run saves and switches nothing.
                model.setAuto(false)
                if let device = (model.devices[.input] ?? []).last { model.setHidden(true, device) }
                model.showsHidden = true
                panel(model, dark: false, to: folder.appendingPathComponent("panel-manual-hidden-light.png"))
                panel(model, dark: true, to: folder.appendingPathComponent("panel-manual-hidden-dark.png"))
                capsules(model, to: folder.appendingPathComponent("capsule-manual.png"))
            }
            print("Wrote snapshots to \(folder.path)")
            NSApp.terminate(nil)
        }
    }

    private static func panel(_ model: AppModel, dark: Bool, to url: URL) {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let view = PanelView(model: model)
            .background(Color(nsColor: dark ? NSColor(white: 0.14, alpha: 1) : NSColor(white: 0.95, alpha: 1)))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: view)
        host.appearance = appearance
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// The capsule at 4×, on a light and a dark menu bar.
    private static func capsules(_ model: AppModel, to url: URL) {
        let face = StatusItemController.face(of: model)
        let capsule = Glyphs.capsule(output: face.output, input: face.input, isManual: face.isManual)
        let image = Bitmap.draw(width: 144, height: 30, scale: 4) { context in
            for (index, isDark) in [false, true].enumerated() {
                let bar = CGRect(x: CGFloat(index) * 72, y: 0, width: 72, height: 30)
                context.setFillColor(CGColor(gray: isDark ? 0.15 : 0.92, alpha: 1))
                context.fill(bar)
                let rect = CGRect(x: bar.midX - 24, y: 6, width: 48, height: 18)
                // A template image is one ink: draw it, then tint what was drawn.
                context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
                capsule.draw(in: rect)
                context.setBlendMode(.sourceIn)
                context.setFillColor(CGColor(gray: isDark ? 1 : 0, alpha: 1))
                context.fill(rect)
                context.endTransparencyLayer()
                context.setBlendMode(.normal)
            }
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return }
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
