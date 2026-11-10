import Foundation

/// A synthetic-only boundary for exercising enable, disable and reset behavior.
/// It never posts OS events, and cannot be enabled for physical input.
public struct SimulationSession: Sendable {
    public private(set) var isEnabled = false
    private var engine: RuleEngine

    public init(configuration: MACEvoConfiguration) throws {
        engine = try RuleEngine(configuration: configuration)
    }

    public mutating func enable() { isEnabled = true }

    public mutating func disable(at timestampMicros: UInt64) -> [ActionIntent] {
        guard isEnabled else { return [] }
        isEnabled = false
        return [engine.reset(at: timestampMicros, reason: "simulation-disabled")]
    }

    public mutating func process(_ event: InputEvent) throws -> [ActionIntent] {
        guard event.source == .synthetic else {
            throw ConfigurationError.invalidEvent("simulation accepts synthetic input only")
        }
        guard isEnabled else { return [] }
        return try engine.process(event)
    }
}
