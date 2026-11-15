import AppKit
import AudioPriorityCore

/// `--selftest <folder>`: opens the real panel and drives it with synthetic
/// mouse events, the way a hand would, then says what happened. Dry run only,
/// so the clicks change nothing on the Mac. It checks the parts unit tests
/// cannot reach: that a click on a row selects it, that dragging a row
/// re-ranks it, and that the level slider follows the pointer.
@MainActor
enum SelfTest {
    static func run(model: AppModel, panel: PanelController, button: NSStatusBarButton, folder: URL) {
        guard model.isDryRun else {
            print("selftest: refused. Run it with AUDIO_PRIORITY_DRY_RUN=1 so it cannot change your audio devices.")
            NSApp.terminate(nil)
            return
        }
        Task {
            await model.loadBluetooth()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // The panel closes when another app becomes active, which also happens
            // just after launch, so let that settle and reopen it if it was closed.
            try? await Task.sleep(for: .milliseconds(1500))
            for _ in 0..<3 where !panel.isVisible {
                panel.show(below: button)
                try? await Task.sleep(for: .milliseconds(700))
            }
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0 is NSPanel }), let view = window.contentView else {
                print("selftest: FAIL. The panel did not stay open (a click in another app closes it). Run it again and keep your hands off.")
                NSApp.terminate(nil)
                return
            }
            var failures = 0
            func check(_ name: String, _ passed: Bool, _ detail: String) {
                print("selftest: \(passed ? "pass" : "FAIL") · \(name) · \(detail)")
                if !passed { failures += 1 }
            }
            capture(view, to: folder.appendingPathComponent("selftest-1-open.png"))

            // The layout from the top of the panel: 10 pt padding, two 30 pt
            // sliders 8 pt apart, then each list's heading and 38 pt rows.
            let sliderY: CGFloat = 25
            let outputs = model.visibleDevices(.headphones) + model.visibleDevices(.speakers)
            let inputs = model.visibleDevices(.microphones)
            let outputTop: CGFloat = 10 + 30 + 8 + 30 + 6 + 20
            func rowY(_ index: Int, top: CGFloat) -> CGFloat { top + CGFloat(index) * 39 + 19 }
            let inputTop = outputTop + CGFloat(outputs.count) * 39 + 13 + 20

            // 1. The slider follows the pointer.
            if model.volume[.output] != nil {
                await click(window, x: 78, y: sliderY)
                let low = model.volume[.output] ?? -1
                await click(window, x: 234, y: sliderY)
                let high = model.volume[.output] ?? -1
                check("slider", abs(low - 0.25) < 0.05 && abs(high - 0.75) < 0.05, "a click at 25% gave \(low), at 75% gave \(high)")
            } else {
                print("selftest: skip · slider · the output in use has no volume control")
            }

            // 2. A click on a row asks for that device.
            if let other = outputs.enumerated().first(where: { !model.isCurrent($0.element) && $0.element.isConnected }) {
                let before = Log.count
                await click(window, x: 150, y: rowY(other.offset, top: outputTop))
                let line = Log.lines.dropFirst(before).first { $0.contains("would switch output to \(other.element.name)") }
                check("click a row", line != nil, line ?? "no switch to \(other.element.name) was asked for; log: \(Log.lines.dropFirst(before))")
            } else {
                print("selftest: skip · click a row · there is no second connected output")
            }

            // 3. Dragging the last input row to the top re-ranks it.
            if inputs.count >= 2, let last = inputs.last {
                await drag(window, x: 150, fromY: rowY(inputs.count - 1, top: inputTop), toY: rowY(0, top: inputTop) - 6)
                try? await Task.sleep(for: .milliseconds(400))
                let now = model.visibleDevices(.microphones)
                check("drag a row", now.first == last, "order is now \(now.map(\.name))")
            } else {
                print("selftest: skip · drag a row · fewer than two inputs")
            }
            capture(view, to: folder.appendingPathComponent("selftest-2-after.png"))

            print("selftest: \(failures == 0 ? "all checks passed" : "\(failures) check(s) FAILED")")
            NSApp.terminate(nil)
        }
    }

    // MARK: Synthetic input

    /// `y` is measured down from the top of the panel, as the layout is.
    private static func event(_ type: NSEvent.EventType, _ window: NSWindow, x: CGFloat, y: CGFloat) -> NSEvent? {
        NSEvent.mouseEvent(
            with: type, location: NSPoint(x: x, y: window.frame.height - y), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
        )
    }

    private static func post(_ type: NSEvent.EventType, _ window: NSWindow, x: CGFloat, y: CGFloat) async {
        if let event = event(type, window, x: x, y: y) { NSApp.postEvent(event, atStart: false) }
        try? await Task.sleep(for: .milliseconds(30))
    }

    private static func click(_ window: NSWindow, x: CGFloat, y: CGFloat) async {
        await post(.leftMouseDown, window, x: x, y: y)
        await post(.leftMouseUp, window, x: x, y: y)
        try? await Task.sleep(for: .milliseconds(250))
    }

    private static func drag(_ window: NSWindow, x: CGFloat, fromY: CGFloat, toY: CGFloat) async {
        await post(.leftMouseDown, window, x: x, y: fromY)
        let steps = 12
        for step in 1...steps {
            await post(.leftMouseDragged, window, x: x, y: fromY + (toY - fromY) * CGFloat(step) / CGFloat(steps))
        }
        await post(.leftMouseUp, window, x: x, y: toY)
    }

    private static func capture(_ view: NSView, to url: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// What the app has logged this run, kept so the self-test can read it back.
@MainActor
enum Log {
    private(set) static var lines: [String] = []
    static var count: Int { lines.count }

    static func write(_ message: String) {
        lines.append(message)
        FileHandle.standardError.write(Data("Audio Priority: \(message)\n".utf8))
    }
}
