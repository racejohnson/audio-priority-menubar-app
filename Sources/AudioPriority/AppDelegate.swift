import AppKit

@main
@MainActor
enum AudioPriorityMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `AUDIO_PRIORITY_DRY_RUN=1` reads the real devices but never switches,
    /// changes volume, connects, saves settings or touches the login item.
    private let model = AppModel(isDryRun: ProcessInfo.processInfo.environment["AUDIO_PRIORITY_DRY_RUN"] == "1")
    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private var terminationSignal: (any DispatchSourceSignal)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        // `--snapshot <folder>` writes pictures of the panel and capsule and quits.
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(flag + 1) {
            Snapshot.write(model: model, to: URL(fileURLWithPath: arguments[flag + 1]))
            return
        }
        let panel = PanelController(model: model)
        let statusItem = StatusItemController(model: model, panel: panel)
        self.statusItem = statusItem
        self.panel = panel
        terminateOnSIGTERM()
        // `--selftest <folder>` drives the real panel with synthetic clicks (dry run only) and quits.
        if let flag = arguments.firstIndex(of: "--selftest"), arguments.indices.contains(flag + 1), let button = statusItem.button {
            SelfTest.run(model: model, panel: panel, button: button, folder: URL(fileURLWithPath: arguments[flag + 1]))
        }
    }

    /// `kill` and `make install` send SIGTERM; route it through the normal quit.
    private func terminateOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }
}
