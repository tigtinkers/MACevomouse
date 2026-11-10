import AppKit
import CoreGraphics
import IOKit.hid
import MACEvoCore
import MACEvoHIDBridge

/// A bounded attribution probe followed by an explicitly enabled wheel-click experiment.
/// No keyboard input mask; unrelated mouse events are returned immediately and never logged.
@MainActor final class LiveShortcutAdapter: ObservableObject {
    @Published var status = "Disabled — native mouse behavior"
    @Published var isEnabled = false
    @Published var isProbing = false
    @Published var probeVerified = false
    @Published var probeLog: [String] = []
    private var router = ShortcutRouter()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var device: IOHIDDevice?
    private var registryID: UInt64 = 0
    private var generation = 0
    private var downs = 0
    private var ups = 0
    private var probeHeld = false
    private var probeUnexpected = false
    private var observerTokens: [NSObjectProtocol] = []
    private let monitor = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    static let marker: Int64 = 0x4d414345564f

    init() {
        IOHIDManagerSetDeviceMatching(monitor, [kIOHIDVendorIDKey: 0x1a7c, kIOHIDProductIDKey: 0x0191] as CFDictionary)
        IOHIDManagerRegisterDeviceRemovalCallback(monitor, { context, _, _, removed in
            guard let context else { return }
            let owner = Unmanaged<LiveShortcutAdapter>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                if let selected = owner.device, CFEqual(selected, removed) { owner.disable(reason: "Device disconnected — select and probe again", fault: true) }
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(monitor, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(monitor, IOOptionBits(kIOHIDOptionsTypeNone))
        observerTokens.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.disable() }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observerTokens.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.disable(reason: "Session changed — re-enable manually", fault: true) }
            })
        }
    }

    deinit {
        for token in observerTokens { NSWorkspace.shared.notificationCenter.removeObserver(token); NotificationCenter.default.removeObserver(token) }
        IOHIDManagerRegisterDeviceRemovalCallback(monitor, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(monitor, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(monitor, IOOptionBits(kIOHIDOptionsTypeNone))
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    func requestPermissions() {
        // Called only by the explicit user-facing permissions button.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        _ = CGRequestListenEventAccess()
        status = "Check Accessibility and Input Monitoring permissions, then retry the probe."
    }

    func probe(_ selected: IOHIDDevice) {
        disable(reason: "Preparing attribution probe")
        guard MACEvoHasSenderAttribution() else { status = "Attribution unavailable on this macOS version"; return }
        let service = IOHIDDeviceGetService(selected)
        guard service != 0, IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS, registryID != 0 else {
            status = "Cannot identify selected interface"; return
        }
        device = selected
        downs = 0; ups = 0; probeHeld = false; probeUnexpected = false; probeLog = []
        isProbing = true
        let current = generation
        status = "Probe starts in 3 seconds — then click the wheel once; leave other devices idle"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.generation == current else { return }
            guard self.installTap(listenOnly: true) else { self.disable(reason: "Probe unavailable — check Input Monitoring permission", fault: true); return }
            self.status = "Probing for 10 seconds — press and release the wheel click once"
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, self.generation == current else { return }
                self.removeTap()
                self.isProbing = false
                self.probeVerified = self.downs == 1 && self.ups == 1 && !self.probeHeld && !self.probeUnexpected
                self.status = self.probeVerified ? "One selected-device wheel-click pair observed; confirm the physical trial below" : "Probe inconclusive — expected exactly one selected-device button 4 down/up pair"
            }
        }
    }

    func enable(shortcut: KeyboardShortcut) {
        guard probeVerified, let device, isPresent(device), AXIsProcessTrusted() else {
            status = "Enable requires a successful probe, connected device and Accessibility permission"; return
        }
        do { try router.prepare(sender: registryID, shortcut: shortcut) } catch { status = error.localizedDescription; return }
        guard installTap(listenOnly: false) else { disable(reason: "Cannot create remapping tap", fault: true); return }
        router.enable(); isEnabled = true
        status = "Experimental wheel-click shortcut enabled; other controls and scrolling use native behavior"
    }

    func disable(reason: String = "Disabled — native mouse behavior", fault: Bool = false) {
        generation += 1; removeTap(); router.disable(fault: fault)
        isEnabled = false; isProbing = false; probeVerified = false; device = nil; registryID = 0
        status = reason
    }

    private func isPresent(_ device: IOHIDDevice) -> Bool {
        let devices = IOHIDManagerCopyDevices(monitor) as? Set<IOHIDDevice> ?? []
        return devices.contains(device)
    }

    private func installTap(listenOnly: Bool) -> Bool {
        removeTap()
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let created = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
            options: listenOnly ? .listenOnly : .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<LiveShortcutAdapter>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { owner.handle(type: type, event: event) }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        guard let source else { removeTap(); return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }
    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            disable(reason: "Event tap stopped — native behavior restored; probe again", fault: true)
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return Unmanaged.passUnretained(event) }
        let sender = MACEvoEventSender(event)
        guard sender != 0, sender == registryID else { return Unmanaged.passUnretained(event) }
        guard let device, isPresent(device) else {
            disable(reason: "Device no longer present", fault: true); return Unmanaged.passUnretained(event)
        }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let phase: ButtonPhase = type == .otherMouseDown ? .down : .up
        if isProbing {
            if probeLog.count < 20 { probeLog.append("Selected device: host button \(button), \(phase.rawValue)") }
            if button != 4 { probeUnexpected = true }
            if button == 4 {
                if phase == .down { downs += 1; probeHeld = true } else { ups += 1; probeHeld = false }
            }
            return Unmanaged.passUnretained(event)
        }
        if isEnabled && !AXIsProcessTrusted() {
            disable(reason: "Accessibility permission unavailable", fault: true)
            return Unmanaged.passUnretained(event)
        }
        switch router.route(sender: sender, button: button, phase: phase) {
        case .passthrough: return Unmanaged.passUnretained(event)
        case .suppress: return nil
        case .fire(let shortcut):
            // Allocate both events before suppressing the native input.
            guard let outputs = Self.makeEvents(shortcut) else {
                disable(reason: "Could not construct shortcut — native behavior restored", fault: true)
                return Unmanaged.passUnretained(event)
            }
            for output in outputs {
                output.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                output.post(tap: .cghidEventTap)
            }
            return nil
        }
    }
    static func makeEvents(_ shortcut: KeyboardShortcut) -> [CGEvent]? {
        guard (try? shortcut.validate()) != nil, let code = keyCodes[shortcut.key],
              let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return nil }
        var flags: CGEventFlags = []
        for modifier in shortcut.modifiers {
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .control: flags.insert(.maskControl)
            case .option: flags.insert(.maskAlternate)
            case .shift: flags.insert(.maskShift)
            }
        }
        for event in [down, up] {
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
        }
        return [down, up]
    }
    static let keyCodes: [String: CGKeyCode] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,
        "q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,
        "9":25,"7":26,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,"return":36,"l":37,"j":38,"k":40,
        "n":45,"m":46,"tab":48,"space":49,"delete":51,"escape":53,
        "f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,"f7":98,"f8":100,"f9":101,"f10":109,"f11":103,"f12":111,
        "left":123,"right":124,"down":125,"up":126
    ]
}
