import Foundation

public struct RawCaptureRecord: Codable, Equatable, Sendable {
    public var elapsedMicros: UInt64
    public var sample: RawHIDValue
}

/// A diagnostic document, deliberately distinct from a replay fixture.
public struct RawCaptureDocument: Codable, Sendable {
    public var schemaVersion = 1
    public var source = InputSource.physicalMacOS
    public var trial: String
    public var interfaceReference = "selected-interface"
    public var vendorID: Int
    public var productID: Int
    public var includeMovement: Bool
    public var records: [RawCaptureRecord] = []
    public var omittedValues = 0
    public init(trial: String, vendorID: Int, productID: Int, includeMovement: Bool) {
        self.trial = trial; self.vendorID = vendorID; self.productID = productID; self.includeMovement = includeMovement
    }
}

public struct RawCaptureBuffer {
    public private(set) var document: RawCaptureDocument
    private let startTicks: UInt64
    private let nanosPerTick: Double
    private let capacity: Int
    private var last: [UInt32: (UInt64, Int)] = [:]
    public init(document: RawCaptureDocument, startTicks: UInt64, timebaseNumerator: UInt32, timebaseDenominator: UInt32, capacity: Int = 250) {
        self.document = document; self.startTicks = startTicks
        nanosPerTick = Double(timebaseNumerator) / Double(max(1, timebaseDenominator))
        self.capacity = max(0, capacity)
    }
    @discardableResult public mutating func append(_ sample: RawHIDValue, elementID: UInt32, ticks: UInt64) -> RawCaptureRecord? {
        guard ticks >= startTicks else { return nil }
        guard sample.usagePage == 1 || sample.usagePage == 9 || (sample.usagePage == 12 && sample.usage == 568) else { return nil }
        if !document.includeMovement && sample.usagePage == 1 && [48,49].contains(sample.usage) { return nil }
        if let previous = last[elementID], previous.0 == ticks && previous.1 == sample.value { return nil }
        last[elementID] = (ticks, sample.value)
        guard document.records.count < capacity else { document.omittedValues += 1; return nil }
        let micros = Double(ticks - startTicks) * nanosPerTick / 1000
        guard micros.isFinite, micros >= 0, micros < Double(UInt64.max) else { return nil }
        let record = RawCaptureRecord(elapsedMicros: UInt64(micros), sample: sample)
        document.records.append(record)
        return record
    }
}
