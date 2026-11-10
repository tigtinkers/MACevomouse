import SwiftUI
import MACEvoCore

private enum PreviewAction: String, CaseIterable, Identifiable {
    case passThrough = "Default button"
    case shortcut = "Keyboard shortcut"
    case systemAction = "Mac action"
    case disabled = "Disabled"
    var id: String { rawValue }
}

private struct Assignment {
    var action: PreviewAction = .passThrough
    var shortcut: String = "command+left"
    var systemAction: String = "mission-control"
}

private let controlNames: [Control: String] = [
    .topFinger: "Top finger", .middleFinger: "Middle finger", .bottomFinger: "Bottom finger",
    .wheelClick: "Wheel click", .upperThumb: "Upper thumb", .lowerThumb: "Lower thumb"
]

/// Design and synthetic rule-engine exercise only: never connected to HID or OS output.
struct AssignmentPreview: View {
    @State private var primaryAssignments = Dictionary(uniqueKeysWithValues: Control.allCases.map { ($0, Assignment()) })
    @State private var secondaryAssignments = Dictionary(uniqueKeysWithValues: Control.allCases.map { ($0, Assignment()) })
    @State private var selected: Control = .topFinger
    @State private var layer: MappingLayer = .primary
    @State private var secondary = false
    @State private var thumbWheel = true
    @State private var output = "Select a button, choose an assignment, then run a simulated press."

    private func binding(_ control: Control) -> Binding<Assignment> {
        Binding(get: { (layer == .primary ? primaryAssignments[control] : secondaryAssignments[control]) ?? Assignment() }, set: {
            if layer == .primary { primaryAssignments[control] = $0 } else { secondaryAssignments[control] = $0 }
        })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Controls").font(.headline)
                ForEach(Control.allCases, id: \.self) { control in
                    Button { selected = control } label: {
                        HStack {
                            Text(controlNames[control] ?? control.rawValue)
                            Spacer()
                            if selected == control { Image(systemName: "checkmark") }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(8)
                        .background(selected == control ? Color.accentColor.opacity(0.16) : Color.clear)
                        .cornerRadius(6)
                }
                Spacer()
            }.frame(width: 190)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Synthetic assignment preview").font(.title2)
                Text("Mockup only: no device is connected, changes are not saved, and no input is remapped.")
                    .foregroundStyle(.secondary)
                Text(controlNames[selected] ?? selected.rawValue).font(.headline)
                Text("Physical identity: not yet confirmed").foregroundStyle(.secondary)
                Toggle("Use lower thumb as secondary layer", isOn: $secondary)
                if secondary {
                    Picker("Layer", selection: $layer) {
                        Text("Normal").tag(MappingLayer.primary)
                        Text("While lower thumb is held").tag(MappingLayer.secondary)
                    }.pickerStyle(.segmented)
                }
                Picker("Action", selection: binding(selected).action) {
                    ForEach(PreviewAction.allCases) { Text($0.rawValue).tag($0) }
                }
                if binding(selected).wrappedValue.action == .shortcut {
                    TextField("Keyboard chord (e.g. command+shift+z)", text: binding(selected).shortcut)
                    Text("Enter a chord as text. Key recording and validation are not implemented.").font(.caption).foregroundStyle(.secondary)
                }
                if binding(selected).wrappedValue.action == .systemAction {
                    Picker("Mac action", selection: binding(selected).systemAction) {
                        Text("Mission Control").tag("mission-control")
                        Text("Application windows").tag("app-windows")
                        Text("Show desktop").tag("show-desktop")
                    }
                }
                Toggle("Simulate lower thumb + wheel as horizontal", isOn: $thumbWheel)
                Button("Simulate selected button") { simulateButton() }
                Button("Simulate lower thumb + wheel") { simulateWheel() }
                Text("Simulation result").font(.headline)
                Text(output).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding()
    }

    private func configuration() -> MACEvoConfiguration {
        let mappings: [ButtonMapping] = [MappingLayer.primary, .secondary].flatMap { mappingLayer in
            Control.allCases.compactMap { control -> ButtonMapping? in
            let assignment = (mappingLayer == .primary ? primaryAssignments[control] : secondaryAssignments[control]) ?? Assignment()
            let action: MappingAction
            switch assignment.action {
            case .passThrough: return nil
            case .shortcut: action = MappingAction(kind: .shortcut, value: assignment.shortcut)
            case .systemAction: action = MappingAction(kind: .systemAction, value: assignment.systemAction)
            case .disabled: action = MappingAction(kind: .disabled)
            }
            return ButtonMapping(control: control, phase: .down, layer: mappingLayer, action: action)
            }
        }
        let profile = Profile(id: "preview", device: DeviceMatch(reference: "preview"), secondaryLayerControl: secondary ? .lowerThumb : nil, thumbWheelBehavior: thumbWheel ? .convertVerticalToHorizontal : .preserveHostAxes, mappings: mappings)
        return MACEvoConfiguration(profiles: [profile])
    }

    private func show(_ events: [InputEvent]) {
        do {
            var session = try SimulationSession(configuration: configuration())
            session.enable()
            let intents = try events.flatMap { try session.process($0) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            output = String(decoding: try encoder.encode(intents), as: UTF8.self)
        } catch { output = "Cannot simulate: \(error.localizedDescription)" }
    }
    private func simulateButton() {
        let device = DeviceIdentity(reference: "preview")
        var events: [InputEvent] = []
        if secondary && layer == .secondary && selected != .lowerThumb {
            events.append(InputEvent(timestampMicros: 1, device: device, kind: .hostButton, control: .lowerThumb, phase: .down))
        }
        events.append(InputEvent(timestampMicros: 2, device: device, kind: .hostButton, control: selected, phase: .down))
        events.append(InputEvent(timestampMicros: 3, device: device, kind: .hostButton, control: selected, phase: .up))
        if secondary && layer == .secondary && selected != .lowerThumb {
            events.append(InputEvent(timestampMicros: 4, device: device, kind: .hostButton, control: .lowerThumb, phase: .up))
        }
        show(events)
    }
    private func simulateWheel() {
        let device = DeviceIdentity(reference: "preview")
        show([InputEvent(timestampMicros: 1, device: device, kind: .hostButton, control: .lowerThumb, phase: .down),
              InputEvent(timestampMicros: 2, device: device, kind: .hostScroll, axis: .vertical, delta: 1),
              InputEvent(timestampMicros: 3, device: device, kind: .hostButton, control: .lowerThumb, phase: .up)])
    }
}
