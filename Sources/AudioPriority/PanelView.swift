import AppKit
import AudioPriorityCore
import SwiftUI

/// The panel: two level sliders, the ranked output and input lists, the
/// switches and a quiet footer.
struct PanelView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.auto { Banner(text: "Auto is off. Devices stay where you put them.") }
            if let note = model.takeoverNote { Banner(text: note) }

            VStack(spacing: 8) {
                LevelSlider(model: model, role: .output)
                LevelSlider(model: model, role: .input)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 6)

            DeviceSection(model: model, role: .output, title: "Output", hint: "headphones first")
            Rule()
            DeviceSection(model: model, role: .input, title: "Input", hint: "held when AirPods connect")
            Rule()

            VStack(spacing: 8) {
                SwitchRow(
                    title: "Auto Switch",
                    hint: model.auto ? "Uses your top-ranked devices" : "Off: devices stay where you put them",
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

    /// The colour of text that sits on a `.primary` fill.
    static let onPrimary = dynamic(light: 0xFFFFFF, dark: 0x000000)

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
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
    }
}

private struct SwitchRow: View {
    let title: String
    var hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
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
        .toggleStyle(.switch)
        .controlSize(.mini)
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
                    withAnimation(.snappy(duration: 0.2)) { model.showsHidden.toggle() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help(model.showsHidden ? "Put the hidden devices away" : "Show the hidden devices")
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
                Capsule().fill(.primary.opacity(0.08))
                label(device).foregroundStyle(.primary)
                // The filled part, with the same label on top in the opposite
                // colour, so the text stays readable across the edge.
                Rectangle()
                    .fill(.primary.opacity(0.92))
                    .frame(width: width)
                label(device)
                    .foregroundStyle(Color.onPrimary)
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
        .accessibilityRepresentation {
            Slider(value: Binding(get: { Double(level ?? 0) }, set: { model.setVolume(Float($0), role) })) {
                Text(role == .output ? "Output volume, \(device?.name ?? "no output")" : "Input level, \(device?.name ?? "no microphone")")
            }
            .disabled(level == nil)
        }
        .help(level == nil && device != nil ? "\(device?.name ?? "") has no level control of its own" : "")
    }

    private func label(_ device: AudioDevice?) -> some View {
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
            Image(systemName: role == .output ? "speaker.wave.2.fill" : "mic.fill")
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.6)
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
                    .animation(isDragged ? nil : .snappy(duration: 0.2), value: target)
                    .gesture(DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            drag = Drag(id: device.id, from: drag?.id == device.id ? drag?.from ?? index : index, offset: value.translation.height)
                        }
                        .onEnded { _ in
                            guard let ended = drag else { return }
                            let destination = self.target(of: ended, count: list.count)
                            drag = nil
                            if destination != ended.from {
                                withAnimation(.snappy(duration: 0.2)) { model.move(device, toVisibleIndex: destination) }
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

    var body: some View {
        let isCurrent = model.isCurrent(device)
        let isHidden = model.isHidden(device)
        let isDimmed = isHidden || !device.isConnected
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
                .opacity(isDimmed ? 0.42 : 1)

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
            .opacity(isDimmed ? 0.42 : 1)

            Spacer(minLength: 2)
            trailing(isCurrent: isCurrent, isHidden: isHidden)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.height)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrent ? AnyShapeStyle(Color.role(device.role)) : AnyShapeStyle(.primary.opacity(isHovering || isLifted ? 0.055 : 0)))
                .shadow(color: .black.opacity(isLifted ? 0.18 : 0), radius: 6, y: 2)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { if !isHidden { model.select(device) } }
        .contextMenu { DeviceMenu(model: model, device: device) }
        .focusable(!isHidden)
        .onKeyPress(keys: [.return, .space]) { _ in
            model.select(device)
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            // Option-Up and Option-Down re-rank; plain arrows move the focus.
            guard press.modifiers.contains(.option) else { return .ignored }
            withAnimation(.snappy(duration: 0.2)) { model.move(device, by: press.key == .upArrow ? -1 : 1) }
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(isHidden ? "hidden" : isCurrent ? "in use" : model.detail(for: device))\(rank.map { ", rank \($0)" } ?? "")")
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var detail: some View {
        if device.isConnected, !model.isHidden(device), !model.isConnecting(device),
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
    private func trailing(isCurrent: Bool, isHidden: Bool) -> some View {
        if isHidden {
            Button("Show") {
                withAnimation(.snappy(duration: 0.2)) { model.setHidden(false, device) }
            }
            .buttonStyle(PillButtonStyle())
        } else {
            if model.isConnecting(device) {
                ProgressView().controlSize(.small)
            } else if model.canConnect(device) {
                Button("Connect") { model.select(device) }
                    .buttonStyle(PillButtonStyle())
            }
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
            .opacity(isHovering ? 1 : 0)
            .help("Actions for \(device.name)")
            .accessibilityLabel("Actions for \(device.name)")
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
                .disabled(isCurrent || !(device.isConnected || model.canConnect(device)))
            if device.transport == .bluetooth, device.bluetoothAddress != nil {
                Button(device.isConnected ? "Disconnect" : "Connect") { model.setConnected(!device.isConnected, device) }
                    .disabled(model.isConnecting(device))
            }
            Divider()
            Button("Move Up") { withAnimation(.snappy(duration: 0.2)) { model.move(device, by: -1) } }
                .disabled(!model.canMove(device, by: -1))
            Button("Move Down") { withAnimation(.snappy(duration: 0.2)) { model.move(device, by: 1) } }
                .disabled(!model.canMove(device, by: 1))
            if device.role == .output {
                let other: DeviceCategory = device.category == .headphones ? .speakers : .headphones
                Button(other == .headphones ? "Rank with Headphones" : "Rank with Speakers") {
                    withAnimation(.snappy(duration: 0.2)) { model.setCategory(other, device) }
                }
            }
            Divider()
            Button("Hide") { withAnimation(.snappy(duration: 0.2)) { model.setHidden(true, device) } }
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
