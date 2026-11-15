import AppKit
import AudioPriorityCore
import SwiftUI

/// Template images for device glyphs: system symbols by name, and the one
/// custom drawing, the DJI Mic Mini.
@MainActor
enum Glyphs {
    /// A template image for `key` at `pointSize`. System symbols come at the
    /// given weight; the DJI glyph is drawn to sit beside them.
    static func image(_ key: GlyphKey, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage {
        switch key {
        case .symbol(let name):
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)
                ?? NSImage()
            return image.withSymbolConfiguration(.init(pointSize: pointSize, weight: weight)) ?? image
        case .djiMicMini:
            // The glyph's 18-unit box, sized so its body matches a symbol's cap height.
            return djiMicMini(size: (pointSize * 1.5).rounded(), small: pointSize <= 11)
        }
    }

    /// The DJI Mic Mini transmitter on an 18-unit grid, after Race's drawing:
    /// a rounded-square body with three slots centred near the top, and a
    /// sliver of the magnetic clip behind the top-left corner. `small` is the
    /// cut for the menu bar: wider slots and a wider gap to the clip.
    static func djiMicMini(size: CGFloat, small: Bool) -> NSImage {
        let image = Bitmap.draw(width: size, height: size) { context in
            let unit = size / 18
            // The grid has its origin at the top left.
            context.translateBy(x: 0, y: size)
            context.scaleBy(x: unit, y: -unit)
            let gap: CGFloat = small ? 1.15 : 0.9
            let front = CGRect(x: 3.9, y: 4.1, width: 12.1, height: 11.9)
            context.setFillColor(.black)

            // The clip: the back plate, minus the front body and a gap around it.
            context.addPath(CGPath(roundedRect: CGRect(x: 1.9, y: 1.9, width: 12.1, height: 11.9), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
            context.fillPath()
            context.setBlendMode(.clear)
            context.addPath(CGPath(roundedRect: front.insetBy(dx: -gap, dy: -gap), cornerWidth: 3.5 + gap, cornerHeight: 3.5 + gap, transform: nil))
            context.fillPath()
            context.setBlendMode(.normal)

            // The body, with the three slots cut out of it.
            let slot = CGSize(width: small ? 1.3 : 0.95, height: small ? 3.0 : 2.5)
            let spacing: CGFloat = small ? 2.45 : 1.95
            context.addPath(CGPath(roundedRect: front, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
            for index in -1...1 {
                let rect = CGRect(x: 9.95 + CGFloat(index) * spacing - slot.width / 2, y: 6.6 - slot.height / 2, width: slot.width, height: slot.height)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: slot.width / 2, cornerHeight: slot.width / 2, transform: nil))
            }
            context.fillPath(using: .evenOdd)
        }
        image.isTemplate = true
        return image
    }

    /// The menu-bar capsule, 58 × 22 pt: output on the left, input on the
    /// right. Auto on: a soft 16% fill with solid glyphs. Auto off: the fill
    /// goes solid and the glyphs are cut out of it.
    static func capsule(output: GlyphKey, input: GlyphKey, isManual: Bool) -> NSImage {
        let size = CGSize(width: 58, height: 22)
        let slot: CGFloat = 21, padding: CGFloat = 5.5, middle: CGFloat = 5
        // The DJI glyph keeps its bolder menu-bar cut at this size.
        let glyphs = [output, input].map { $0 == .djiMicMini ? djiMicMini(size: 18, small: true) : image($0, pointSize: 13, weight: .semibold) }
        let capsule = Bitmap.draw(width: size.width, height: size.height) { context in
            let shell = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: size.height / 2, cornerHeight: size.height / 2, transform: nil)
            context.setFillColor(CGColor(gray: 0, alpha: isManual ? 1 : 0.16))
            context.addPath(shell)
            context.fillPath()
            for (index, glyph) in glyphs.enumerated() {
                // A glyph wider than its slot is scaled down to fit.
                let scale = min(1, slot / glyph.size.width, (size.height - 4) / glyph.size.height)
                let fitted = CGSize(width: glyph.size.width * scale, height: glyph.size.height * scale)
                let x = padding + CGFloat(index) * (slot + middle) + (slot - fitted.width) / 2
                let rect = CGRect(x: x, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
                glyph.draw(in: rect, from: .zero, operation: isManual ? .destinationOut : .sourceOver, fraction: 1)
            }
        }
        capsule.isTemplate = true
        return capsule
    }
}

/// Draws into a bitmap at 3×, so the result is sharp on any display and is a
/// plain value that can be handed around.
@MainActor
enum Bitmap {
    static func draw(width: CGFloat, height: CGFloat, scale: CGFloat = 3, _ body: (CGContext) -> Void) -> NSImage {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int((width * scale).rounded(.up)), pixelsHigh: Int((height * scale).rounded(.up)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return image }
        // Set before the context is made, so drawing is in points, not pixels.
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        body(context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        return image
    }
}

/// A device glyph in SwiftUI, tinted by the foreground style around it.
struct GlyphView: View {
    let key: GlyphKey
    var pointSize: CGFloat = 10
    var weight: NSFont.Weight = .semibold

    var body: some View {
        Image(nsImage: Glyphs.image(key, pointSize: pointSize, weight: weight))
            .renderingMode(.template)
            .accessibilityHidden(true)
    }
}
