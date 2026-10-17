import Foundation

/// A non-secret identifier supplied by the selected input adapter. `vendorID` and
/// `productID` remain optional until live hardware observation confirms them.
public struct DeviceIdentity: Codable, Equatable, Sendable {
    public var reference: String
    public var vendorID: Int?
    public var productID: Int?
    public var transport: String?

    public init(reference: String, vendorID: Int? = nil, productID: Int? = nil, transport: String? = nil) {
        self.reference = reference
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
    }
}

public enum InputSource: String, Codable, Sendable {
    case synthetic
    case physicalLinux = "physical-linux"
    case physicalMacOS = "physical-macos"
}

/// These are guided physical-location labels, not asserted HID usage numbers.
public enum Control: String, Codable, CaseIterable, Sendable {
    case topFinger
    case middleFinger
    case bottomFinger
    case wheelClick
    case upperThumb
    case lowerThumb
}

public enum ButtonPhase: String, Codable, Sendable {
    case down
    case up
}

public enum ScrollAxis: String, Codable, Sendable {
    case vertical
    case horizontal
}

public struct RawHIDValue: Codable, Equatable, Sendable {
    public var reportID: Int?
    public var usagePage: Int
    public var usage: Int
    public var value: Int

    public init(reportID: Int? = nil, usagePage: Int, usage: Int, value: Int) {
        self.reportID = reportID
        self.usagePage = usagePage
        self.usage = usage
        self.value = value
    }
}

/// Raw HID reports and host-translated inputs deliberately use different kinds so
/// a fixture cannot accidentally treat an unverified HID usage as a mapped button.
public enum InputKind: String, Codable, Sendable {
    case rawHID = "raw-hid"
    case hostButton = "host-button"
    case hostScroll = "host-scroll"
    case applicationActivated = "application-activated"
    case deviceDisconnected = "device-disconnected"
}

public struct InputEvent: Codable, Equatable, Sendable {
    public var source: InputSource
    public var timestampMicros: UInt64
    public var device: DeviceIdentity
    public var interface: String?
    public var kind: InputKind
    public var control: Control?
    public var phase: ButtonPhase?
    public var axis: ScrollAxis?
    public var delta: Int?
    public var rawHID: RawHIDValue?
    public var applicationBundleID: String?

    public init(
        source: InputSource = .synthetic,
        timestampMicros: UInt64,
        device: DeviceIdentity,
        interface: String? = nil,
        kind: InputKind,
        control: Control? = nil,
        phase: ButtonPhase? = nil,
        axis: ScrollAxis? = nil,
        delta: Int? = nil,
        rawHID: RawHIDValue? = nil,
        applicationBundleID: String? = nil
    ) {
        self.source = source
        self.timestampMicros = timestampMicros
        self.device = device
        self.interface = interface
        self.kind = kind
        self.control = control
        self.phase = phase
        self.axis = axis
        self.delta = delta
        self.rawHID = rawHID
        self.applicationBundleID = applicationBundleID
    }

    public func validate() throws {
        switch kind {
        case .rawHID:
            guard rawHID != nil else { throw ConfigurationError.invalidEvent("raw-hid requires rawHID") }
        case .hostButton:
            guard control != nil, phase != nil else {
                throw ConfigurationError.invalidEvent("host-button requires control and phase")
            }
        case .hostScroll:
            guard axis != nil, delta != nil else {
                throw ConfigurationError.invalidEvent("host-scroll requires axis and delta")
            }
        case .applicationActivated:
            guard applicationBundleID?.isEmpty == false else {
                throw ConfigurationError.invalidEvent("application-activated requires applicationBundleID")
            }
        case .deviceDisconnected:
            break
        }
    }
}

public enum MappingActionKind: String, Codable, Sendable {
    case passThrough = "pass-through"
    case shortcut
    case systemAction = "system-action"
    case disabled
}

public struct MappingAction: Codable, Equatable, Sendable {
    public var kind: MappingActionKind
    public var value: String?

    public init(kind: MappingActionKind, value: String? = nil) {
        self.kind = kind
        self.value = value
    }
}

public enum MappingLayer: String, Codable, Sendable {
    case primary
    case secondary
}

public struct ButtonMapping: Codable, Equatable, Sendable {
    public var control: Control
    public var phase: ButtonPhase
    public var layer: MappingLayer
    public var action: MappingAction

    public init(control: Control, phase: ButtonPhase, layer: MappingLayer = .primary, action: MappingAction) {
        self.control = control
        self.phase = phase
        self.layer = layer
        self.action = action
    }
}

public enum ThumbWheelBehavior: String, Codable, Sendable {
    /// Synthetic policy only; hardware must establish that lower thumb is observable.
    case convertVerticalToHorizontal = "convert-vertical-to-horizontal"
    /// Preserve host axes when firmware or the OS already provides horizontal scrolling.
    case preserveHostAxes = "preserve-host-axes"
}

public struct ScrollOptions: Codable, Equatable, Sendable {
    public var verticalMultiplier: Double
    public var horizontalMultiplier: Double
    public var reverseVertical: Bool
    public var reverseHorizontal: Bool

    public init(verticalMultiplier: Double = 1, horizontalMultiplier: Double = 1, reverseVertical: Bool = false, reverseHorizontal: Bool = false) {
        self.verticalMultiplier = verticalMultiplier
        self.horizontalMultiplier = horizontalMultiplier
        self.reverseVertical = reverseVertical
        self.reverseHorizontal = reverseHorizontal
    }
}

public struct DeviceMatch: Codable, Equatable, Sendable {
    public var reference: String?
    public var vendorID: Int?
    public var productID: Int?

    public init(reference: String? = nil, vendorID: Int? = nil, productID: Int? = nil) {
        self.reference = reference
        self.vendorID = vendorID
        self.productID = productID
    }

    public func matches(_ device: DeviceIdentity) -> Bool {
        (reference == nil || reference == device.reference)
            && (vendorID == nil || vendorID == device.vendorID)
            && (productID == nil || productID == device.productID)
    }
}

public struct Profile: Codable, Equatable, Sendable {
    public var id: String
    public var priority: Int
    public var device: DeviceMatch?
    public var applicationBundleIDs: [String]
    public var secondaryLayerControl: Control?
    public var thumbWheelBehavior: ThumbWheelBehavior
    public var scroll: ScrollOptions
    public var mappings: [ButtonMapping]

    public init(
        id: String,
        priority: Int = 0,
        device: DeviceMatch? = nil,
        applicationBundleIDs: [String] = [],
        secondaryLayerControl: Control? = nil,
        thumbWheelBehavior: ThumbWheelBehavior = .preserveHostAxes,
        scroll: ScrollOptions = ScrollOptions(),
        mappings: [ButtonMapping] = []
    ) {
        self.id = id
        self.priority = priority
        self.device = device
        self.applicationBundleIDs = applicationBundleIDs
        self.secondaryLayerControl = secondaryLayerControl
        self.thumbWheelBehavior = thumbWheelBehavior
        self.scroll = scroll
        self.mappings = mappings
    }

    func matches(device: DeviceIdentity, applicationBundleID: String?) -> Bool {
        guard self.device == nil || self.device!.matches(device) else { return false }
        return applicationBundleIDs.isEmpty || applicationBundleID.map(applicationBundleIDs.contains) == true
    }
}

public struct EngineSettings: Codable, Equatable, Sendable {
    public var staleHoldTimeoutMicros: UInt64

    public init(staleHoldTimeoutMicros: UInt64 = 2_000_000) {
        self.staleHoldTimeoutMicros = staleHoldTimeoutMicros
    }
}

public struct MACEvoConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var settings: EngineSettings
    public var profiles: [Profile]

    public init(schemaVersion: Int = MACEvoConfiguration.currentSchemaVersion, settings: EngineSettings = EngineSettings(), profiles: [Profile]) {
        self.schemaVersion = schemaVersion
        self.settings = settings
        self.profiles = profiles
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ConfigurationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard settings.staleHoldTimeoutMicros > 0 else {
            throw ConfigurationError.invalidConfiguration("staleHoldTimeoutMicros must be positive")
        }
        let ids = profiles.map(\.id)
        guard Set(ids).count == ids.count, !ids.contains(where: { $0.isEmpty }) else {
            throw ConfigurationError.invalidConfiguration("profile ids must be present and unique")
        }
        for profile in profiles {
            guard profile.scroll.verticalMultiplier.isFinite,
                  profile.scroll.horizontalMultiplier.isFinite,
                  profile.scroll.verticalMultiplier >= 0,
                  profile.scroll.horizontalMultiplier >= 0 else {
                throw ConfigurationError.invalidConfiguration("scroll multipliers must be finite and non-negative")
            }
        }
    }
}

public struct FixtureDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var label: String
    public var source: InputSource
    public var configuration: MACEvoConfiguration
    public var events: [InputEvent]

    public init(schemaVersion: Int = 1, label: String, source: InputSource, configuration: MACEvoConfiguration, events: [InputEvent]) {
        self.schemaVersion = schemaVersion
        self.label = label
        self.source = source
        self.configuration = configuration
        self.events = events
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ConfigurationError.unsupportedFixtureSchemaVersion(schemaVersion) }
        guard !label.isEmpty else { throw ConfigurationError.invalidConfiguration("fixture label is required") }
        try configuration.validate()
        for event in events {
            guard event.source == source else { throw ConfigurationError.invalidEvent("fixture source and event source differ") }
            try event.validate()
        }
    }
}

public enum ConfigurationError: Error, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case unsupportedFixtureSchemaVersion(Int)
    case invalidConfiguration(String)
    case invalidEvent(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version): return "Unsupported configuration schema version: \(version)"
        case .unsupportedFixtureSchemaVersion(let version): return "Unsupported fixture schema version: \(version)"
        case .invalidConfiguration(let message), .invalidEvent(let message): return message
        }
    }
}

public enum IntentKind: String, Codable, Sendable {
    case passThroughButton = "pass-through-button"
    case shortcut
    case systemAction = "system-action"
    case scroll
    case reset
    case diagnostic
}

/// An intention for a future adapter. The core and CLI never post operating-system events.
public struct ActionIntent: Codable, Equatable, Sendable {
    public var timestampMicros: UInt64
    public var kind: IntentKind
    public var control: Control?
    public var phase: ButtonPhase?
    public var axis: ScrollAxis?
    public var delta: Int?
    public var value: String?
    public var transformed: Bool?

    public init(timestampMicros: UInt64, kind: IntentKind, control: Control? = nil, phase: ButtonPhase? = nil, axis: ScrollAxis? = nil, delta: Int? = nil, value: String? = nil, transformed: Bool? = nil) {
        self.timestampMicros = timestampMicros
        self.kind = kind
        self.control = control
        self.phase = phase
        self.axis = axis
        self.delta = delta
        self.value = value
        self.transformed = transformed
    }
}
