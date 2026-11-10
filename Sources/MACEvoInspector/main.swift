import SwiftUI
import AppKit
import IOKit.hid
import MACEvoCore
import UniformTypeIdentifiers
import Darwin
import MACEvoHIDBridge

// Passive enumeration only. Input callbacks are attached only to a user-selected
// device and are stopped automatically; no event tap or exclusive open is used.
@MainActor final class Inspector: ObservableObject {
    struct Device: Identifiable {
        let id: Int
        let handle: IOHIDDevice
        let name: String
        let vendor: Int
        let product: Int
    }
    @Published var devices: [Device] = []
    @Published var selected: Int?
    @Published var lines: [String] = []
    @Published var capturing = false
    @Published var status = "Stopped"
    @Published var includeMovement = false
    private var buffer: RawCaptureBuffer?
    @Published var trial = "T01 — Top finger press and release"
    let trials = ["T01 — Top finger press and release", "T02 — Middle finger press and release", "T03 — Bottom finger press and release", "T04 — Wheel click", "T05 — Upper thumb", "T06 — Lower thumb hold and release", "T07 — Wheel both directions", "T08 — Lower thumb + wheel", "T09 — Release thumb during wheel", "T10 — Pointer speed", "T11 — Click and drag", "T12 — Repeated clicking", "T13 — Reconnect", "T14 — Other pointing device"]
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var selectedHandle: IOHIDDevice?
    private var generation = 0

    init() { refresh() }
    func refresh() {
        stop()
        buffer = nil
        IOHIDManagerSetDeviceMatching(manager, nil)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            lines = ["Unable to enumerate HID devices."]; return
        }
        let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        devices = set.enumerated().map { index, device in
            func number(_ key: String) -> Int { (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0 }
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unnamed HID device"
            return Device(id: index, handle: device, name: name, vendor: number(kIOHIDVendorIDKey), product: number(kIOHIDProductIDKey))
        }.sorted { $0.name < $1.name }
        selected = nil
        lines = []
    }
    func inspectElements() {
        guard let device = devices.first(where: { $0.id == selected }) else { return }
        let elements = IOHIDDeviceCopyMatchingElements(device.handle, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []
        buffer = nil
        lines = ["Element inventory: \(device.name) (VID \(device.vendor), PID \(device.product))", "Metadata only; no input values recorded."]
        let descriptions = elements.map { element in
            "type \(IOHIDElementGetType(element).rawValue), report \(IOHIDElementGetReportID(element)), page \(IOHIDElementGetUsagePage(element)), usage \(IOHIDElementGetUsage(element))"
        }
        lines.append(contentsOf: Set(descriptions).sorted())
        if descriptions.isEmpty { lines.append("No elements returned; access may be unavailable.") }
        status = "Element inventory ready"
    }
    func start() {
        guard let device = devices.first(where: { $0.id == selected }) else { return }
        stop()
        capturing = true
        generation += 1
        let current = generation
        lines = ["Trial: \(trial)", "Selected interface: \(device.name) (VID \(device.vendor), PID \(device.product))", "Raw HID values only; keyboard excluded. Consumer page is limited to AC Pan (usage 568)."]
        buffer = nil
        status = "Get ready — capture starts in 3 seconds"
        for remaining in [2, 1] {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(3 - remaining)) { [weak self] in
                guard let self, self.capturing, self.generation == current else { return }
                self.status = "Get ready — capture starts in \(remaining) seconds"
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.capturing, self.generation == current else { return }
            self.beginCapture(device, generation: current)
        }
    }
    private func beginCapture(_ device: Device, generation current: Int) {
        guard IOHIDDeviceOpen(device.handle, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            lines.append("ERROR: could not open selected device for passive monitoring.")
            stop(); return
        }
        selectedHandle = device.handle
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        buffer = RawCaptureBuffer(document: RawCaptureDocument(trial: trial, vendorID: device.vendor, productID: device.product, includeMovement: includeMovement), startTicks: mach_absolute_time(), timebaseNumerator: timebase.numer, timebaseDenominator: timebase.denom)
        status = "Recording — perform the selected action now"
        IOHIDDeviceRegisterInputValueCallback(device.handle, { context, _, _, value in
            guard let context else { return }
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            // AC Pan is the HID consumer-control horizontal scroll usage.
            // Do not collect keyboard or unrelated consumer controls.
            guard page == 1 || page == 9 || (page == 12 && usage == 0x238) else { return }
            let report = IOHIDElementGetReportID(element)
            let integer = IOHIDValueGetIntegerValue(value)
            let ticks = IOHIDValueGetTimeStamp(value)
            let owner = Unmanaged<Inspector>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                guard owner.capturing else { return }
                let sample = RawHIDValue(reportID: Int(report), usagePage: Int(page), usage: Int(usage), value: integer)
                if let record = owner.buffer?.append(sample, elementID: UInt32(IOHIDElementGetCookie(element)), ticks: ticks) {
                    owner.lines.append("+\(record.elapsedMicros) us, report \(report), page \(page), usage \(usage), value \(integer)")
                }
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device.handle, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, self.generation == current else { return }
            self.stop()
        }
    }
    func exportCapture() {
        guard let document = buffer?.document else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mouse-trial.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(document).write(to: url, options: .atomic)
            status = "Redacted raw capture exported"
        } catch { status = "Export failed: \(error.localizedDescription)" }
    }

    func copyResults() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        status = "Results copied"
    }

    func stop() {
        generation += 1
        let wasCapturing = capturing
        capturing = false
        if wasCapturing {
            let dropped = buffer?.document.omittedValues ?? 0
            if dropped > 0 { lines.append("WARNING: \(dropped) values omitted after the display limit.") }
            status = "Capture stopped"
        }
        if let handle = selectedHandle {
            IOHIDDeviceRegisterInputValueCallback(handle, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(handle, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(handle, IOOptionBits(kIOHIDOptionsTypeNone))
            selectedHandle = nil
        }
    }
}

struct InspectorView: View {
    @ObservedObject var inspector: Inspector
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MACevomouse — passive inspector").font(.title2)
            Text("Select the mouse explicitly. Physical controls and remapping are not yet verified.")
            HStack {
                Picker("Device", selection: $inspector.selected) {
                    Text("Select a device").tag(Optional<Int>.none)
                    ForEach(inspector.devices) { device in
                        Text("\(device.name) (\(device.vendor):\(device.product))").tag(Optional(device.id))
                    }
                }
                .disabled(inspector.capturing)
                Button("Refresh") { inspector.refresh() }.disabled(inspector.capturing)
            }
            Button("Inspect Selected Interface Elements") { inspector.inspectElements() }
                .disabled(inspector.selected == nil || inspector.capturing)
            Picker("Physical trial", selection: $inspector.trial) {
                ForEach(inspector.trials, id: \.self) { Text($0).tag($0) }
            }.disabled(inspector.capturing)
            Toggle("Include pointer movement (X/Y)", isOn: $inspector.includeMovement).disabled(inspector.capturing)
            HStack {
                Button("Capture for 10 seconds") { inspector.start() }.disabled(inspector.selected == nil || inspector.capturing)
                Button("Stop") { inspector.stop() }.disabled(!inspector.capturing)
                Button("Copy Results") { inspector.copyResults() }.disabled(inspector.capturing || inspector.lines.isEmpty)
                Button("Export JSON") { inspector.exportCapture() }.disabled(inspector.capturing)
                Text(inspector.status)
            }
            Text("Remapping unavailable until device attribution and safety are verified.").foregroundStyle(.secondary)
            ScrollView { Text(inspector.lines.joined(separator: "\n")).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
        }.padding().frame(minWidth: 620, minHeight: 360)
    }
}

@main struct InspectorApp: App {
    @StateObject private var inspector = Inspector()
    init() {
        if CommandLine.arguments.contains("--check-attribution") {
            print(MACEvoHasSenderAttribution() ? "Optional sender-attribution symbols available; hardware matching remains unverified." : "Sender-attribution symbols unavailable; live remapping is disabled.")
            exit(0)
        }
    }
    var body: some Scene {
        WindowGroup {
            TabView {
                InspectorView(inspector: inspector).tabItem { Label("Hardware trials", systemImage: "dot.radiowaves.left.and.right") }
                ScrollTest().tabItem { Label("Scroll test", systemImage: "arrow.left.and.right") }
                ShortcutSettings(inspector: inspector).tabItem { Label("Assignments", systemImage: "keyboard") }
                AssignmentPreview().tabItem { Label("Assignment preview", systemImage: "slider.horizontal.3") }
            }.frame(minWidth: 720, minHeight: 480)
        }
    }
}
