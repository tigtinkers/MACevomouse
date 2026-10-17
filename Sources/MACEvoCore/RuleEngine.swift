import Foundation

public struct RuleEngine: Sendable {
    public private(set) var configuration: MACEvoConfiguration
    public private(set) var activeApplicationBundleID: String?
    private var heldControls: [Control: UInt64] = [:]
    private var lastTimestampMicros: UInt64?

    public init(configuration: MACEvoConfiguration, activeApplicationBundleID: String? = nil) throws {
        try configuration.validate()
        self.configuration = configuration
        self.activeApplicationBundleID = activeApplicationBundleID
    }

    public var heldControlSnapshot: Set<Control> { Set(heldControls.keys) }

    public mutating func process(_ event: InputEvent) throws -> [ActionIntent] {
        try event.validate()
        if let lastTimestampMicros, event.timestampMicros < lastTimestampMicros {
            // Applying late state transitions can create a false chord or leave a
            // button latched. Future adapters should provide a monotonic stream;
            // until then this conservative core records and ignores late input.
            return [diagnostic(event, "out-of-order-timestamp-ignored")]
        }
        var intents = recoverStaleHolds(at: event.timestampMicros)
        lastTimestampMicros = event.timestampMicros

        if event.kind == .applicationActivated {
            let next = event.applicationBundleID!
            if next != activeApplicationBundleID, !heldControls.isEmpty {
                heldControls.removeAll()
                intents.append(ActionIntent(timestampMicros: event.timestampMicros, kind: .reset, value: "application-profile-changed"))
            }
            activeApplicationBundleID = next
            return intents
        }

        guard let profile = selectedProfile(for: event.device) else {
            intents.append(diagnostic(event, "ignored-unselected-device"))
            return intents
        }

        switch event.kind {
        case .rawHID:
            intents.append(diagnostic(event, "raw-hid-observed-not-interpreted"))
        case .hostButton:
            intents.append(contentsOf: processButton(event, profile: profile))
        case .hostScroll:
            intents.append(processScroll(event, profile: profile))
        case .deviceDisconnected:
            if !heldControls.isEmpty { heldControls.removeAll() }
            intents.append(ActionIntent(timestampMicros: event.timestampMicros, kind: .reset, value: "device-disconnected"))
        case .applicationActivated:
            break
        }
        return intents
    }

    private func selectedProfile(for device: DeviceIdentity) -> Profile? {
        configuration.profiles
            .filter { $0.matches(device: device, applicationBundleID: activeApplicationBundleID) }
            .sorted { lhs, rhs in lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority > rhs.priority }
            .first
    }

    private mutating func processButton(_ event: InputEvent, profile: Profile) -> [ActionIntent] {
        let control = event.control!
        let phase = event.phase!
        switch phase {
        case .down:
            guard heldControls[control] == nil else { return [diagnostic(event, "duplicate-button-down")] }
            heldControls[control] = event.timestampMicros
            return intentForButton(event, profile: profile)
        case .up:
            guard heldControls[control] != nil else { return [diagnostic(event, "button-up-without-down")] }
            let intents = intentForButton(event, profile: profile)
            heldControls.removeValue(forKey: control)
            return intents
        }
    }

    private func intentForButton(_ event: InputEvent, profile: Profile) -> [ActionIntent] {
        let control = event.control!
        let phase = event.phase!
        let layer: MappingLayer = isSecondaryLayerActive(profile) ? .secondary : .primary
        let action = profile.mappings.first { $0.control == control && $0.phase == phase && $0.layer == layer }?.action
            ?? MappingAction(kind: .passThrough)
        switch action.kind {
        case .passThrough:
            return [ActionIntent(timestampMicros: event.timestampMicros, kind: .passThroughButton, control: control, phase: phase)]
        case .shortcut:
            return [ActionIntent(timestampMicros: event.timestampMicros, kind: .shortcut, control: control, phase: phase, value: action.value)]
        case .systemAction:
            return [ActionIntent(timestampMicros: event.timestampMicros, kind: .systemAction, control: control, phase: phase, value: action.value)]
        case .disabled:
            return [diagnostic(event, "mapping-disabled")]
        }
    }

    private func processScroll(_ event: InputEvent, profile: Profile) -> ActionIntent {
        var axis = event.axis!
        var transformed = false
        if axis == .vertical, heldControls[.lowerThumb] != nil, profile.thumbWheelBehavior == .convertVerticalToHorizontal {
            axis = .horizontal
            transformed = true
        }
        let multiplier = axis == .vertical ? profile.scroll.verticalMultiplier : profile.scroll.horizontalMultiplier
        let reversed = axis == .vertical ? profile.scroll.reverseVertical : profile.scroll.reverseHorizontal
        let signedMultiplier = reversed ? -multiplier : multiplier
        let scaledDelta = boundedRoundedDelta(event.delta!, multiplier: signedMultiplier)
        return ActionIntent(timestampMicros: event.timestampMicros, kind: .scroll, axis: axis, delta: scaledDelta, transformed: transformed)
    }

    private func boundedRoundedDelta(_ delta: Int, multiplier: Double) -> Int {
        let scaled = Double(delta) * multiplier
        if scaled >= Double(Int.max) { return Int.max }
        if scaled <= Double(Int.min) { return Int.min }
        return Int(scaled.rounded())
    }

    private func isSecondaryLayerActive(_ profile: Profile) -> Bool {
        profile.secondaryLayerControl.map { heldControls[$0] != nil } ?? false
    }

    private mutating func recoverStaleHolds(at timestamp: UInt64) -> [ActionIntent] {
        let timeout = configuration.settings.staleHoldTimeoutMicros
        let stale = heldControls.filter { timestamp >= $0.value && timestamp - $0.value > timeout }.map(\.key)
        guard !stale.isEmpty else { return [] }
        for control in stale { heldControls.removeValue(forKey: control) }
        return stale.map {
            ActionIntent(timestampMicros: timestamp, kind: .diagnostic, control: $0, value: "recovered-missing-release")
        }
    }

    private func diagnostic(_ event: InputEvent, _ message: String) -> ActionIntent {
        ActionIntent(timestampMicros: event.timestampMicros, kind: .diagnostic, control: event.control, value: message)
    }
}
