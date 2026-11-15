// Renders the SF Symbols the mock-up needs to white-on-clear PNGs (used as
// masks, so they take any ink) and writes assets/sf.json.
// Run: swift docs/2-refine-2026-11-15/source/sf-export.swift
// The PNGs are Apple's system symbols, for this private mock-up only; the app
// asks macOS for them by name.
import AppKit

let names = [
  "laptopcomputer", "display", "mic", "mic.fill", "airpods.pro", "airpods", "airpod.right", "airpods.max",
  "headphones", "iphone", "hifispeaker", "hifispeaker.fill", "speaker.wave.2.fill", "speaker.wave.3.fill",
  "checkmark", "airpods.pro.chargingcase.wireless", "wifi", "battery.100percent", "switch.2", "sun.max.fill",
  "line.3.horizontal", "cable.connector", "tv", "homepod.fill",
]
struct Cfg { let key: String; let pt: CGFloat; let weight: NSFont.Weight }
// cap: inside the menu-bar capsule. row: panel rows and menu-bar neighbours.
let cfgs = [Cfg(key: "cap", pt: 10, weight: .semibold), Cfg(key: "row", pt: 13, weight: .medium)]
let scale: CGFloat = 6
var out: [String: [String: Any]] = [:]
for n in names {
  var entry: [String: Any] = [:]
  for c in cfgs {
    guard let base = NSImage(systemSymbolName: n, accessibilityDescription: nil),
          let img = base.withSymbolConfiguration(.init(pointSize: c.pt, weight: c.weight)) else {
      FileHandle.standardError.write("missing \(n)\n".data(using: .utf8)!); continue
    }
    let s = img.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(s.width * scale)), pixelsHigh: Int(ceil(s.height * scale)),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = s
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(origin: .zero, size: s))
    NSColor.white.set()
    NSRect(origin: .zero, size: s).fill(using: .sourceIn)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    entry[c.key] = ["w": s.width, "h": s.height, "uri": "data:image/png;base64," + png.base64EncodedString()]
  }
  out[n] = entry
}
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
try data.write(to: here.appendingPathComponent("assets/sf.json"))
for n in names { if let e = out[n], let c = e["cap"] as? [String: Any], let r = e["row"] as? [String: Any] { print(n, "cap", c["w"]!, c["h"]!, "row", r["w"]!, r["h"]!) } }
print("sf.json", data.count / 1024, "KB")
