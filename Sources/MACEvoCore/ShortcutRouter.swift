import Foundation

public enum ShortcutRouterState: String, Sendable { case disabled, ready, enabled, faulted }
public enum ButtonRoute: Equatable, Sendable {
    case passthrough
    case suppress
    case fire(KeyboardShortcut)
}

/// First hardware experiment: only the observed wheel-click CG button candidate.
/// Caller supplies an independently resolved sender identity, never a timing guess.
public struct ShortcutRouter: Sendable {
    public private(set) var state: ShortcutRouterState = .disabled
    private var sender: UInt64 = 0
    private var shortcut: KeyboardShortcut?
    private var held = false
    public init() {}
    public mutating func prepare(sender: UInt64, shortcut: KeyboardShortcut) throws {
        try shortcut.validate()
        guard sender != 0 else { throw ConfigurationError.invalidConfiguration("Missing device identity") }
        self.sender = sender; self.shortcut = shortcut; held = false; state = .ready
    }
    public mutating func enable() { if state == .ready { state = .enabled } }
    public mutating func disable(fault: Bool = false) {
        state = fault ? .faulted : .disabled; sender = 0; shortcut = nil; held = false
    }
    public mutating func route(sender: UInt64, button: Int, phase: ButtonPhase, generated: Bool = false) -> ButtonRoute {
        guard state == .enabled, !generated, sender != 0, sender == self.sender, button == 4,
              let shortcut else { return .passthrough }
        switch phase {
        case .down:
            guard !held else { return .suppress }
            held = true; return .fire(shortcut)
        case .up:
            guard held else { return .passthrough }
            held = false; return .suppress
        }
    }
}
