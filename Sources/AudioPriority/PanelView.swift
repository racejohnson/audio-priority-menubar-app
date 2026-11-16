import AppKit
import AudioPriorityCore
import SwiftUI

/// The panel: two level sliders, the ranked output and input lists, the
/// switches and a quiet footer.
struct PanelView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.auto { Banner(text: "Auto Switch is off. Devices stay put.") }
            if let note = model.takeoverNote { Banner(text: note) }

            VStack(spacing: 8) {
                LevelSlider(model: model, role: .output)
                LevelSlider(model: model, role: .input)
            }
            .padding(.bottom, 6)

            DeviceSection(model: model, role: .output, title: "Output", hint: "headphones first")
            Rule()
            DeviceSection(model: model, role: .input, title: "Input", hint: "held when AirPods connect")
            Rule()

            VStack(spacing: 8) {
                SwitchRow(
                    title: "Auto Switch",
                    hint: model.auto ? "Uses your top-ranked devices" : "The microphone is still held",
                    isOn: Binding(get: { model.auto }, set: model.setAuto)
                )
                LaunchAtLoginRow(launchAtLogin: model.launchAtLogin)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)

            Rule()
            Footer(model: model)
        }
        .padding(10)
        .frame(width: 312)
        // The panel takes key focus without activating the app; without this its
        // controls would draw in the inactive (grey) style.
        .environment(\.controlActiveState, .key)
    }
}

// MARK: Colours

extension Color {
    /// Blue for output, violet for input; brighter in dark mode.
    static func role(_ role: Role) -> Color {
        role == .output ? dynamic(light: 0x2F6FE4, dark: 0x4B8DFF) : dynamic(light: 0x6A4FD8, dark: 0x9479F0)
    }

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1
            )
        })
    }
}

// MARK: Motion

@MainActor
enum Motion {
    /// The panel's one animation, or none when the user has asked macOS to reduce motion.
    static var glide: Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .snappy(duration: 0.2)
    }
}

// MARK: Small pieces

private struct Rule: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

private struct Banner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.primary.opacity(0.075)))
            .padding(.bottom, 8)
    }
}

private struct SwitchRow: View {
    let title: String
    var hint: String?
    @Binding var isOn: Bool
    @Environment(\.drawsSwitchesForPictures) private var drawsSwitch

    var body: some View {
        let toggle = Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if drawsSwitch {
            toggle.toggleStyle(DrawnSwitchStyle())
        } else {
            toggle.toggleStyle(.switch).controlSize(.mini)
        }
    }
}

extension EnvironmentValues {
    /// True in the off-screen pictures (`--snapshot`, `--readme`), where the
    /// system switch draws grey because its window is not the key window.
    @Entry var drawsSwitchesForPictures = false
}

/// A stand-in for the system's mini switch as it looks in the open panel.
private struct DrawnSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Capsule()
                .fill(configuration.isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary.opacity(0.16)))
                .frame(width: 36, height: 17)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: 22, height: 13)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                        .padding(2)
                }
        }
    }
}

private struct LaunchAtLoginRow: View {
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SwitchRow(title: "Open at Login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: launchAtLogin.setEnabled))
            if let issue = launchAtLogin.issue {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(issue.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if issue == .needsApproval {
                        Button("Open Login Items", action: launchAtLogin.openLoginItems)
                            .buttonStyle(.link)
                    }
                }
                .font(.system(size: 11))
            }
        }
    }
}

private struct Footer: View {
    let model: AppModel
    @State private var isHoveringQuit = false

    var body: some View {
        let outputs = model.connectedCount(.output), inputs = model.connectedCount(.input), hidden = model.hiddenCount
        HStack(spacing: 0) {
            Text("\(outputs) output\(outputs == 1 ? "" : "s") · \(inputs) input\(inputs == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            if hidden > 0 {
                Text(" · ").foregroundStyle(.secondary)
                Button("\(hidden) hidden") {
                    withAnimation(Motion.glide) { model.showsHidden.toggle() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help(model.showsHidden ? "Put the hidden devices away" : "Show the hidden devices")
                .accessibilityLabel("\(hidden) hidden device\(hidden == 1 ? "" : "s")")
                .accessibilityValue(model.showsHidden ? "showing" : "not showing")
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(isHoveringQuit ? .primary : .secondary)
                .onHover { isHoveringQuit = $0 }
                .help("Quit Audio Priority (⌘Q)")
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, 2)
    }
}

// MARK: Level slider

/// A Control Center–style slider that also says which device is in use.
private struct LevelSlider: View {
    let model: AppModel
    let role: Role

    var body: some View {
        let device = model.currentDevice(role)
        let level = model.volume[role]
        GeometryReader { geometry in
            let width = geometry.size.width * CGFloat(level ?? 0)
            ZStack(alignment: .leading) {
                // A device with no level of its own gets a fainter, empty track.
                Capsule().fill(.primary.opacity(level == nil ? 0.05 : 0.08))
                // The label is drawn twice, each copy clipped to its own side of
                // the edge, so the text stays readable across it and neither
                // copy shows through the other.
                label(device, hasLevel: level != nil)
                    .foregroundStyle(.primary)
                    .mask(alignment: .trailing) { Rectangle().frame(width: max(geometry.size.width - width, 0)) }
                // White in both appearances, as in Control Center. A plain
                // colour, because `.primary` goes grey on glass.
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: width)
                label(device, hasLevel: level != nil)
                    .foregroundStyle(Color.black)
                    .mask(alignment: .leading) { Rectangle().frame(width: width) }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard level != nil, geometry.size.width > 0 else { return }
                model.setVolume(Float(min(max(value.location.x / geometry.size.width, 0), 1)), role)
            })
        }
        .frame(height: 30)
        // Focus comes from the keyboard only (Tab, with keyboard navigation
        // on), so a click leaves no focus ring behind.
        .focusable(level != nil, interactions: .activate)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            guard let level else { return .ignored }
            // A sixteenth, as the volume keys step; Option steps by one percent.
            let step: Float = press.modifiers.contains(.option) ? 0.01 : 1.0 / 16
            let isUp = press.key == .rightArrow || press.key == .upArrow
            model.setVolume(min(max(level + (isUp ? step : -step), 0), 1), role)
            return .handled
        }
        .accessibilityRepresentation {
            // The same sixteenth the arrow keys and the volume keys step by.
            Slider(value: Binding(get: { Double(level ?? 0) }, set: { model.setVolume(Float($0), role) }), in: 0...1, step: 1.0 / 16) {
                Text(role == .output ? "Output volume, \(device?.name ?? "no output")" : "Input level, \(device?.name ?? "no microphone")")
            }
            .disabled(level == nil)
            .accessibilityHint(level == nil && device != nil ? "\(device?.name ?? "") has no \(role == .output ? "volume" : "input level") control of its own" : "")
        }
        // The name in full, since a long one is cut short in the slider.
        .help(device.map { level == nil ? "\($0.name) has no \(role == .output ? "volume" : "input level") control of its own" : $0.name } ?? "")
    }

    private func label(_ device: AudioDevice?, hasLevel: Bool) -> some View {
        HStack(spacing: 8) {
            GlyphView(
                key: device.map(model.glyph(for:)) ?? .symbol(role == .output ? "speaker.slash.fill" : "mic.slash.fill"),
                pointSize: 12, weight: .medium
            )
            .frame(width: 24)
            Text(device?.name ?? (role == .output ? "No output" : "No microphone"))
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            if hasLevel {
                Image(systemName: role == .output ? "speaker.wave.2.fill" : "mic.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.6)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Device lists

private struct DeviceSection: View {
    let model: AppModel
    let role: Role
    let title: String
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 3)

            let categories = DeviceCategory.categories(for: role)
            ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                // Ranks run on from Headphones into Speakers.
                let firstRank = categories.prefix(index).reduce(1) { $0 + model.visibleDevices($1).count }
                RankedRows(model: model, category: category, firstRank: firstRank)
            }
            if model.showsHidden {
                ForEach(model.hiddenDevices(role)) { device in
                    DeviceRow(model: model, device: device, rank: nil)
                        .transition(.opacity)
                }
            }
        }
    }
}

/// One list's visible rows. There is no handle: a row is dragged by itself.
private struct RankedRows: View {
    let model: AppModel
    let category: DeviceCategory
    let firstRank: Int

    private struct Drag: Equatable {
        var id: DeviceID
        var from: Int
        var offset: CGFloat
    }

    @State private var drag: Drag?
    private static let step = DeviceRow.height + 1

    var body: some View {
        let list = model.visibleDevices(category)
        let target = drag.map { target(of: $0, count: list.count) }
        VStack(spacing: 1) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, device in
                let isDragged = drag?.id == device.id
                DeviceRow(model: model, device: device, rank: firstRank + index, isLifted: isDragged)
                    .offset(y: offset(of: index, count: list.count, target: target))
                    .zIndex(isDragged ? 1 : 0)
                    .animation(isDragged ? nil : Motion.glide, value: target)
                    .gesture(DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            drag = Drag(id: device.id, from: drag?.id == device.id ? drag?.from ?? index : index, offset: value.translation.height)
                        }
                        .onEnded { _ in
                            guard let ended = drag else { return }
                            let destination = self.target(of: ended, count: list.count)
                            drag = nil
                            if destination != ended.from {
                                withAnimation(Motion.glide) { model.move(device, toVisibleIndex: destination) }
                            }
                        })
            }
        }
    }

    /// The index the dragged row would land on.
    private func target(of drag: Drag, count: Int) -> Int {
        min(max(drag.from + Int((drag.offset / Self.step).rounded()), 0), count - 1)
    }

    private func offset(of index: Int, count: Int, target: Int?) -> CGFloat {
        guard let drag, let target else { return 0 }
        if index == drag.from {
            // The dragged row follows the pointer, but stays inside its list.
            return min(max(drag.offset, -CGFloat(drag.from) * Self.step), CGFloat(count - 1 - drag.from) * Self.step)
        }
        // The rows it passes step aside.
        if drag.from < index, index <= target { return -Self.step }
        if target <= index, index < drag.from { return Self.step }
        return 0
    }
}

private struct DeviceRow: View {
    static let height: CGFloat = 38

    let model: AppModel
    let device: AudioDevice
    /// Nil for a hidden device, which has no rank to show.
    let rank: Int?
    var isLifted = false

    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @FocusState private var menuIsFocused: Bool

    var body: some View {
        let isCurrent = model.isCurrent(device)
        let isHidden = model.isHidden(device)
        let isDimmed = isHidden || !device.isConnected || model.isMicOff(device)
        // Dimmed less on the filled row, where white at 42% would be hard to read.
        let dim: Double = isDimmed ? (isCurrent ? 0.7 : 0.42) : 1
        // ⋯ shows while the pointer is on the row, or the keyboard is.
        let showsActions = !isHidden && (isHovering || isFocused || menuIsFocused)
        // Whether choosing the row would do anything.
        let canUse = isCurrent || (!isHidden && !model.isMicOff(device) && (device.isConnected || model.canConnect(device)))
        HStack(spacing: 8) {
            Text(rank.map(String.init) ?? "")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? AnyShapeStyle(.white.opacity(0.62)) : AnyShapeStyle(.tertiary))
                .frame(width: 12)

            GlyphView(key: model.glyph(for: device))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 26, height: 26)
                .background(Circle().fill(isCurrent ? AnyShapeStyle(.white.opacity(0.24)) : AnyShapeStyle(.primary.opacity(0.075))))
                .opacity(dim)

            VStack(alignment: .leading, spacing: 0) {
                Text(device.name)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                    .lineLimit(1)
                detail
                    .font(.system(size: 11))
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
            .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .opacity(dim)

            Spacer(minLength: 2)
            trailing(isHidden: isHidden)
            // Room for ⋯ only while it shows, so a long name gets the full row at rest.
            if showsActions { Color.clear.frame(width: 14, height: 1) }
        }
        // The right edge lines up with the headings, rules and switches.
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(height: Self.height)
        .overlay(alignment: .trailing) {
            if !isHidden { actions(isCurrent: isCurrent, isShown: showsActions).padding(.trailing, 8) }
        }
        .background {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            ZStack {
                // A lifted row is solid, so the rows it passes do not show through it.
                if isLifted, !isCurrent { shape.fill(Color(nsColor: .windowBackgroundColor)) }
                shape.fill(isCurrent ? AnyShapeStyle(Color.role(device.role)) : AnyShapeStyle(.primary.opacity(isHovering || isLifted || isFocused ? 0.055 : 0)))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(isLifted ? 0.22 : 0), radius: 6, y: 2)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            // A click focuses the row; let go, so its fill does not outstay the pointer.
            isFocused = false
            if !isHidden { model.select(device) }
        }
        // One tooltip for the whole row: the reason it cannot be used, what a
        // click does, or the name in full when it is cut short.
        .help(
            isHidden ? device.name
                : model.isMicOff(device) ? "The receiver is plugged in, but the microphone is switched off"
                : model.canConnect(device) ? "Click to connect and use \(device.name)" : device.name
        )
        .contextMenu { DeviceMenu(model: model, device: device) }
        .focusable(!isHidden)
        .focused($isFocused)
        // No system focus ring: a click focuses the row, and the ring then
        // reads as a stray border. A focused row takes the hover fill instead.
        .focusEffectDisabled()
        .onKeyPress(keys: [.return, .space]) { _ in
            guard canUse else { return .ignored }
            model.select(device)
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            // Option-Up and Option-Down re-rank; Tab moves between rows.
            guard press.modifiers.contains(.option) else { return .ignored }
            withAnimation(Motion.glide) { model.move(device, by: press.key == .upArrow ? -1 : 1) }
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel(isCurrent: isCurrent, isHidden: isHidden))
        // What the ⋯ menu offers besides Use (which is the row's own action),
        // for VoiceOver's actions rotor.
        .accessibilityActions {
            if isHidden {
                Button("Show") { model.setHidden(false, device) }
            } else {
                if device.transport == .bluetooth, device.bluetoothAddress != nil, !model.isConnecting(device) {
                    Button(device.isConnected ? "Disconnect" : "Connect") { model.setConnected(!device.isConnected, device) }
                }
                if model.canMove(device, by: -1) { Button("Move Up") { model.move(device, by: -1) } }
                if model.canMove(device, by: 1) { Button("Move Down") { model.move(device, by: 1) } }
                if device.role == .output {
                    let other: DeviceCategory = device.category == .headphones ? .speakers : .headphones
                    Button(other == .headphones ? "Rank with Headphones" : "Rank with Speakers") { model.setCategory(other, device) }
                }
                Button("Hide") { model.setHidden(true, device) }
            }
        }
        // Only a row that can be chosen is a button.
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : canUse || isHidden ? .isButton : [])
    }

    private func spokenLabel(isCurrent: Bool, isHidden: Bool) -> String {
        let battery = device.isConnected && !isHidden && !model.isConnecting(device) ? model.battery(for: device)?.text : nil
        var parts = [device.name]
        if isHidden {
            parts.append("hidden")
        } else {
            if isCurrent { parts.append("in use") }
            if let battery {
                parts.append("battery \(battery)")
            } else if !isCurrent || model.transmitter(for: device) != nil {
                // A wireless microphone's state (charging, low battery, mic off) is said even when in use.
                parts.append(model.detail(for: device))
            }
        }
        if let rank { parts.append("rank \(rank)") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var detail: some View {
        if !model.isHidden(device), let status = model.transmitter(for: device) {
            transmitterDetail(status)
        } else if device.isConnected, !model.isHidden(device), !model.isConnecting(device),
           let battery = model.battery(for: device), let text = battery.text {
            HStack(spacing: 3) {
                Image(systemName: Self.batterySymbol(battery.lowest ?? 100))
                    .font(.system(size: 10))
                Text(text)
            }
        } else {
            Text(model.detail(for: device))
        }
    }

    @ViewBuilder
    private func trailing(isHidden: Bool) -> some View {
        if isHidden {
            Button("Show") {
                withAnimation(Motion.glide) { model.setHidden(false, device) }
            }
            .buttonStyle(PillButtonStyle())
        } else if model.isConnecting(device) {
            ProgressView().controlSize(.small)
        }
    }

    /// The ⋯ button, which shows while the pointer is on the row.
    private func actions(isCurrent: Bool, isShown: Bool) -> some View {
            Menu {
                DeviceMenu(model: model, device: device)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(isCurrent ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            .opacity(isShown ? 1 : 0)
            .focused($menuIsFocused)
            .help("Actions for \(device.name)")
            .accessibilityLabel("Actions for \(device.name)")
    }

    /// The second line of a wireless microphone's row: a battery mark for the
    /// receiver's seven steps (it gives no percentage), and what it is doing.
    @ViewBuilder
    private func transmitterDetail(_ status: TransmitterStatus) -> some View {
        let isLow = status.isLinked && status.isLow && !status.isCharging
        let line = HStack(spacing: 3) {
            if status.isLinked, let percent = status.estimatedPercent {
                Image(systemName: status.isCharging ? "battery.100percent.bolt" : Self.batterySymbol(percent))
                    .font(.system(size: 10))
            }
            Text(model.detail(for: device))
        }
        if isLow {
            // Yellow reads on the filled row of the microphone in use; orange elsewhere.
            line.foregroundStyle(model.isCurrent(device) ? Color.yellow : Color.orange)
        } else {
            line
        }
    }

    private static func batterySymbol(_ level: Int) -> String {
        switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

/// The row's actions, shared by the ⋯ button and the right-click menu.
private struct DeviceMenu: View {
    let model: AppModel
    let device: AudioDevice

    var body: some View {
        if model.isHidden(device) {
            Button("Show") { model.setHidden(false, device) }
        } else {
            let isCurrent = model.isCurrent(device)
            Button(isCurrent ? "In Use" : "Use") { model.select(device) }
                .disabled(isCurrent || model.isMicOff(device) || !(device.isConnected || model.canConnect(device)))
            if device.transport == .bluetooth, device.bluetoothAddress != nil {
                Button(device.isConnected ? "Disconnect" : "Connect") { model.setConnected(!device.isConnected, device) }
                    .disabled(model.isConnecting(device))
            }
            Divider()
            Button("Move Up") { withAnimation(Motion.glide) { model.move(device, by: -1) } }
                .disabled(!model.canMove(device, by: -1))
            Button("Move Down") { withAnimation(Motion.glide) { model.move(device, by: 1) } }
                .disabled(!model.canMove(device, by: 1))
            if device.role == .output {
                let other: DeviceCategory = device.category == .headphones ? .speakers : .headphones
                Button(other == .headphones ? "Rank with Headphones" : "Rank with Speakers") {
                    withAnimation(Motion.glide) { model.setCategory(other, device) }
                }
            }
            Divider()
            Button("Hide") { withAnimation(Motion.glide) { model.setHidden(true, device) } }
        }
    }
}

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(Capsule().fill(.background.opacity(configuration.isPressed ? 0.6 : 1)).shadow(color: .black.opacity(0.14), radius: 0.75, y: 0.5))
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
    }
}
