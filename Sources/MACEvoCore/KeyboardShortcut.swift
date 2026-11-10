import Foundation

public enum ShortcutModifier: String, Codable, CaseIterable, Sendable {
    case command, control, option, shift
}

/// Physical ANSI key names, independent of the user's current keyboard layout.
public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public let modifiers: [ShortcutModifier]
    public let key: String

    public static let supportedKeys = Set(Array("abcdefghijklmnopqrstuvwxyz0123456789").map(String.init)
        + ["left", "right", "up", "down", "space", "return", "tab", "escape", "delete"]
        + (1...12).map { "f\($0)" })

    public init(text: String) throws {
        let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let key = parts.last, Self.supportedKeys.contains(key) else {
            throw ConfigurationError.invalidConfiguration("Use one supported letter, digit, arrow, F1–F12, space, return, tab, escape or delete key.")
        }
        var modifiers = Set<ShortcutModifier>()
        for part in parts.dropLast() {
            guard let modifier = ShortcutModifier(rawValue: part), modifiers.insert(modifier).inserted else {
                throw ConfigurationError.invalidConfiguration("Use command, control, option or shift once each, followed by one key.")
            }
        }
        self.modifiers = ShortcutModifier.allCases.filter(modifiers.contains)
        self.key = key
    }

    public var text: String { (modifiers.map(\.rawValue) + [key]).joined(separator: "+") }
    public func validate() throws {
        guard try Self(text: text) == self else {
            throw ConfigurationError.invalidConfiguration("Shortcut modifiers must be unique and in canonical order.")
        }
    }
}

public struct ShortcutBinding: Codable, Equatable, Sendable {
    public var control: Control
    public var shortcut: KeyboardShortcut
    public var isDictation: Bool
    public init(control: Control, shortcut: KeyboardShortcut, isDictation: Bool = false) {
        self.control = control; self.shortcut = shortcut; self.isDictation = isDictation
    }
}

public struct ShortcutProfile: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var vendorID = 0x1a7c
    public var productID = 0x0191
    public var bindings: [ShortcutBinding] = []
    public init(bindings: [ShortcutBinding] = []) { self.bindings = bindings }
    public func validate() throws {
        guard schemaVersion == 1, vendorID == 0x1a7c, productID == 0x0191 else {
            throw ConfigurationError.invalidConfiguration("Unsupported profile version or device. This profile targets the observed 6780:401 mouse only.")
        }
        guard Set(bindings.map(\.control)).count == bindings.count,
              !bindings.contains(where: { $0.control == .lowerThumb }) else {
            throw ConfigurationError.invalidConfiguration("Duplicate controls or reserved lower thumb binding.")
        }
        for binding in bindings { try binding.shortcut.validate() }
    }

    public static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        // Legacy core configurations are imported only when every mapping is representable.
        if let legacy = try? decoder.decode(MACEvoConfiguration.self, from: data) {
            try legacy.validate()
            guard legacy.profiles.count == 1, let source = legacy.profiles.first,
                  source.applicationBundleIDs.isEmpty, source.secondaryLayerControl == nil,
                  source.thumbWheelBehavior == .preserveHostAxes,
                  source.scroll == ScrollOptions(), source.device?.vendorID == 0x1a7c,
                  source.device?.productID == 0x0191 else {
                throw ConfigurationError.invalidConfiguration("Legacy profile cannot be safely imported into the shortcut MVP.")
            }
            var result = Self()
            for mapping in source.mappings {
                guard mapping.layer == .primary, mapping.phase == .down else {
                    throw ConfigurationError.invalidConfiguration("Legacy layers are not supported by the shortcut MVP.")
                }
                switch mapping.action.kind {
                case .passThrough: continue
                case .shortcut:
                    result.bindings.append(ShortcutBinding(control: mapping.control, shortcut: try KeyboardShortcut(text: mapping.action.value ?? "")))
                default: throw ConfigurationError.invalidConfiguration("Legacy action requires manual migration.")
                }
            }
            try result.validate()
            return result
        }
        let result = try decoder.decode(Self.self, from: data)
        try result.validate()
        return result
    }
}

/// Failed loads or saves never replace the in-memory last valid profile.
public struct ShortcutProfileStore {
    public let url: URL
    public private(set) var current = ShortcutProfile()
    public init(url: URL) { self.url = url }
    public mutating func load() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        current = try ShortcutProfile.decode(Data(contentsOf: url))
    }
    public mutating func save(_ profile: ShortcutProfile) throws {
        try profile.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        current = profile
    }
}
