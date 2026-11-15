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
        let arguments = CommandLine.arguments
        if model.isDryRun {
            // A dry run changes nothing, so it may run beside the real app.
        } else if let flag = ["--snapshot", "--selftest", "--readme"].first(where: arguments.contains) {
            print("\(flag): refused. Run it with AUDIO_PRIORITY_DRY_RUN=1 so it cannot change your audio devices.")
            NSApp.terminate(nil)
            return
        } else if let bundleID = Bundle.main.bundleIdentifier,
                  NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0 != .current }) {
            // Two copies would both switch devices and each draw a capsule.
            NSApp.terminate(nil)
            return
        }
        // `--readme <folder>` draws the README's pictures from made-up devices and quits.
        if let flag = arguments.firstIndex(of: "--readme"), arguments.indices.contains(flag + 1) {
            ReadmePictures.write(model: model, to: URL(fileURLWithPath: arguments[flag + 1]))
            return
        }
        model.start()
        // `--snapshot <folder>` writes pictures of the panel and capsule and quits.
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

    /// `kill` sends SIGTERM; route it through the normal quit.
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
