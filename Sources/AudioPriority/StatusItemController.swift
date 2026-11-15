import AppKit
import AudioPriorityCore
import Observation

/// The menu-bar capsule: the output device on the left, the input device on
/// the right. Clicking it opens the panel.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private let panel: PanelController

    /// What the capsule depends on, so it is redrawn only when one of them changes.
    struct Face: Equatable {
        var output: GlyphKey
        var input: GlyphKey
        var isManual: Bool
        var label: String
    }

    init(model: AppModel, panel: PanelController) {
        self.model = model
        self.panel = panel
        super.init()

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        panel.onVisibilityChange = { [weak button] isVisible in
            button?.highlight(isVisible)
        }
        Task { [weak self, model] in
            for await face in Observations({ Self.face(of: model) }) {
                self?.show(face)
            }
        }
    }

    static func face(of model: AppModel) -> Face {
        let output = model.currentDevice(.output), input = model.currentDevice(.input)
        return Face(
            output: output.map(model.glyph(for:)) ?? .symbol("speaker.slash.fill"),
            input: input.map(model.glyph(for:)) ?? .symbol("mic.slash.fill"),
            isManual: !model.auto,
            label: "Out: \(output?.name ?? "none") · In: \(input?.name ?? "none")\(model.auto ? "" : " · Auto off")"
        )
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        panel.toggle(below: sender)
    }

    private func show(_ face: Face) {
        guard let button = item.button else { return }
        button.image = Glyphs.capsule(output: face.output, input: face.input, isManual: face.isManual)
        button.toolTip = face.label
        button.setAccessibilityLabel("Audio Priority. \(face.label)")
    }
}
