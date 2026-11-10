import SwiftUI
import MACEvoCore

private let buttonLabels: [Control: String] = [.topFinger: "Top finger", .middleFinger: "Middle finger", .bottomFinger: "Bottom finger", .wheelClick: "Wheel click", .upperThumb: "Upper thumb", .lowerThumb: "Lower thumb"]

struct ShortcutSettings: View {
    @ObservedObject var inspector: Inspector
    @StateObject private var adapter = LiveShortcutAdapter()
    @State private var shortcuts: [Control: String] = [:]
    @State private var dictation: Set<Control> = []
    @State private var dictationConfirmed = false
    @State private var physicalProbeConfirmed = false
    @State private var selected: Control = .wheelClick
    @State private var message = ""
    @State private var recording = false
    @State private var store = ShortcutProfileStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MACevomouse/shortcuts.json"))
    private var selectedDevice: Inspector.Device? { inspector.devices.first { $0.id == inspector.selected } }
    private var eligible: Bool { selectedDevice?.vendor == 0x1a7c && selectedDevice?.product == 0x0191 }
    private var text: Binding<String> {
        Binding(get: { shortcuts[selected] ?? "" }, set: { shortcuts[selected] = $0; disableForEdit() })
    }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Button assignments").font(.headline)
                ForEach(Control.allCases, id: \.self) { control in
                    Button { recording = false; selected = control } label: {
                        VStack(alignment: .leading) {
                            Text(buttonLabels[control] ?? control.rawValue).fontWeight(selected == control ? .bold : .regular)
                            Text(control == .lowerThumb ? "Native horizontal scrolling" : (shortcuts[control]?.isEmpty == false ? shortcuts[control]! : "Native behavior"))
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.vertical, 4)
                }
                Spacer()
            }.frame(width: 200)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved shortcut assignments").font(.title2)
                    Text("Device: \(selectedDevice?.name ?? "Select an interface in Hardware trials")")
                    Text("Observed raw HID labels apply to 6780:401. Saved assignments alone do not enable remapping.").foregroundStyle(.secondary)
                    Text(buttonLabels[selected] ?? selected.rawValue).font(.headline)
                    if selected == .lowerThumb {
                        Text("Lower thumb remains reserved for the working native wheel chord.")
                    } else {
                        TextField("Shortcut, e.g. command+shift+d; empty preserves native behavior", text: text)
                            .textFieldStyle(.roundedBorder)
                        Text("Physical ANSI keys; command, control, option and shift are supported. Fn-only and repeated-modifier shortcuts are not supported.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(recording ? "Cancel recording" : "Record shortcut in this app") { recording.toggle() }
                        if recording {
                            ShortcutRecorder { result in
                                recording = false
                                switch result {
                                case .success(let shortcut): shortcuts[selected] = shortcut.text; disableForEdit()
                                case .failure(let error): message = error.localizedDescription
                                }
                            }.frame(height: 35)
                            Text("Press a shortcut while the recording box is focused. No background keyboard recording.").font(.caption)
                        }
                        Toggle("Use this assignment for Dictation", isOn: Binding(get: { dictation.contains(selected) }, set: {
                            if $0 { dictation.insert(selected) } else { dictation.remove(selected) }
                            dictationConfirmed = false; disableForEdit()
                        }))
                        if !dictation.isEmpty {
                            Toggle("I confirmed this chord matches my macOS Dictation shortcut", isOn: $dictationConfirmed)
                            Text("Check System Settings → Keyboard → Dictation. Choose a supported key chord there if your shortcut is Fn-only. This app does not change that setting.").font(.caption)
                        }
                    }
                    HStack {
                        Button("Save Assignments") { save() }.disabled(adapter.isEnabled || recording)
                        Button("Restore Defaults") { adapter.disable(); physicalProbeConfirmed = false; shortcuts = [:]; dictation = []; save() }
                    }
                    Text(message).textSelection(.enabled)
                    Divider()
                    Text("First live test: wheel click only").font(.headline)
                    Text("The other assignments can be saved, but only wheel click is available for the first remapping test. Use a harmless shortcut in a test document. Normal scrolling is untouched.")
                    Button("Check / request permissions") { adapter.requestPermissions() }
                    Button("Probe selected mouse for 10 seconds") {
                        guard let device = selectedDevice else { return }
                        physicalProbeConfirmed = false; adapter.probe(device.handle)
                    }.disabled(!eligible || adapter.isProbing || adapter.isEnabled || inspector.capturing)
                    Text(adapter.status)
                    Text(adapter.probeLog.joined(separator: "\n")).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    if adapter.probeVerified {
                        Toggle("I pressed and released only the selected mouse’s wheel click once during the probe", isOn: $physicalProbeConfirmed)
                    }
                    HStack {
                        Button("Enable experimental wheel-click shortcut") { enable() }
                            .disabled(!eligible || !adapter.probeVerified || !physicalProbeConfirmed || adapter.isEnabled || adapter.isProbing || inspector.capturing)
                        Button("Disable now") { adapter.disable(); physicalProbeConfirmed = false }
                    }
                    Text("Starts disabled on every launch. Disconnect, sleep, session change or event-tap failure disables the experiment. Test the other mouse or trackpad before relying on it.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding()
        .onAppear { load() }
        .onDisappear { adapter.disable(); recording = false }
        .onChange(of: inspector.selected) { _ in adapter.disable(); physicalProbeConfirmed = false }
        .onChange(of: inspector.capturing) { value in if value { adapter.disable(); physicalProbeConfirmed = false } }
    }
    private func disableForEdit() { adapter.disable(); physicalProbeConfirmed = false }
    private func draft() throws -> ShortcutProfile {
        if !dictation.isEmpty && !dictationConfirmed { throw ConfigurationError.invalidConfiguration("Confirm your Dictation shortcut before saving.") }
        return ShortcutProfile(bindings: try Control.allCases.compactMap { control in
            let value = (shortcuts[control] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return ShortcutBinding(control: control, shortcut: try MACEvoCore.KeyboardShortcut(text: value), isDictation: dictation.contains(control))
        })
    }
    private func save() {
        do { try store.save(draft()); message = "Assignments saved. Live behavior remains disabled until explicitly enabled." }
        catch { message = "Not saved: \(error.localizedDescription)" }
    }
    private func load() {
        do {
            try store.load()
            shortcuts = Dictionary(uniqueKeysWithValues: store.current.bindings.map { ($0.control, $0.shortcut.text) })
            dictation = Set(store.current.bindings.filter(\.isDictation).map(\.control))
            dictationConfirmed = !dictation.isEmpty
            message = "Loaded saved assignments; remapping is disabled."
        } catch { message = "Could not load settings; file preserved: \(error.localizedDescription)" }
    }
    private func enable() {
        do {
            let profile = try draft(); try profile.validate()
            guard let binding = profile.bindings.first(where: { $0.control == .wheelClick }) else {
                message = "Assign a shortcut to Wheel click first."; return
            }
            // Apply only a successfully saved, validated profile.
            try store.save(profile)
            adapter.enable(shortcut: binding.shortcut)
        } catch { message = "Cannot enable: \(error.localizedDescription)" }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let onRecord: (Result<MACEvoCore.KeyboardShortcut, Error>) -> Void
    func makeNSView(context: Context) -> RecordingView {
        let view = RecordingView(); view.onRecord = onRecord
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ view: RecordingView, context: Context) { view.onRecord = onRecord }
    final class RecordingView: NSView {
        var onRecord: ((Result<MACEvoCore.KeyboardShortcut, Error>) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlBackgroundColor.setFill(); dirtyRect.fill()
            ("Recording here — press your shortcut" as NSString).draw(at: NSPoint(x: 8, y: 8))
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self else { return false }
            keyDown(with: event)
            return true
        }
        override func keyDown(with event: NSEvent) {
            guard !event.isARepeat else { return }
            guard let key = LiveShortcutAdapter.keyCodes.first(where: { $0.value == event.keyCode })?.key else {
                onRecord?(.failure(ConfigurationError.invalidConfiguration("This physical key is not supported."))); return
            }
            var parts: [String] = []
            for (flag, name): (NSEvent.ModifierFlags, String) in [(.command, "command"), (.control, "control"), (.option, "option"), (.shift, "shift")] {
                if event.modifierFlags.contains(flag) { parts.append(name) }
            }
            parts.append(key)
            onRecord?(Result { try MACEvoCore.KeyboardShortcut(text: parts.joined(separator: "+")) })
        }
    }
}
