import XCTest
@testable import MACEvoCore

final class RuleEngineTests: XCTestCase {
    private let device = DeviceIdentity(reference: "synthetic-vmd")

    private func configuration(
        behavior: ThumbWheelBehavior = .convertVerticalToHorizontal,
        timeout: UInt64 = 2_000_000,
        profiles: [Profile]? = nil
    ) -> MACEvoConfiguration {
        MACEvoConfiguration(
            settings: EngineSettings(staleHoldTimeoutMicros: timeout),
            profiles: profiles ?? [Profile(
                id: "selected-synthetic-device",
                device: DeviceMatch(reference: "synthetic-vmd"),
                secondaryLayerControl: .lowerThumb,
                thumbWheelBehavior: behavior
            )]
        )
    }

    private func button(_ control: Control, _ phase: ButtonPhase, at timestamp: UInt64) -> InputEvent {
        InputEvent(timestampMicros: timestamp, device: device, kind: .hostButton, control: control, phase: phase)
    }

    private func scroll(_ axis: ScrollAxis, _ delta: Int, at timestamp: UInt64) -> InputEvent {
        InputEvent(timestampMicros: timestamp, device: device, kind: .hostScroll, axis: axis, delta: delta)
    }

    func testAllSixAbstractControlsPassThroughWithOrderedDownUp() throws {
        var engine = try RuleEngine(configuration: configuration())
        var intents: [ActionIntent] = []
        for (index, control) in Control.allCases.enumerated() {
            intents += try engine.process(button(control, .down, at: UInt64(index * 2 + 1)))
            intents += try engine.process(button(control, .up, at: UInt64(index * 2 + 2)))
        }
        XCTAssertEqual(intents.filter { $0.kind == .passThroughButton }.count, 12)
        XCTAssertTrue(engine.heldControlSnapshot.isEmpty)
    }

    func testLowerThumbConvertsOnlyVerticalWheelToHorizontal() throws {
        var engine = try RuleEngine(configuration: configuration())
        _ = try engine.process(button(.lowerThumb, .down, at: 10))
        let transformed = try engine.process(scroll(.vertical, -4, at: 20))
        let nativeHorizontal = try engine.process(scroll(.horizontal, 6, at: 30))
        XCTAssertEqual(transformed.first?.axis, .horizontal)
        XCTAssertEqual(transformed.first?.delta, -4)
        XCTAssertEqual(transformed.first?.transformed, true)
        XCTAssertEqual(nativeHorizontal.first?.axis, .horizontal)
        XCTAssertEqual(nativeHorizontal.first?.transformed, false)
    }

    func testLowerThumbReleaseRestoresVerticalScrolling() throws {
        var engine = try RuleEngine(configuration: configuration())
        _ = try engine.process(button(.lowerThumb, .down, at: 10))
        _ = try engine.process(button(.lowerThumb, .up, at: 20))
        let intents = try engine.process(scroll(.vertical, 5, at: 30))
        XCTAssertEqual(intents.first?.axis, .vertical)
        XCTAssertEqual(intents.first?.transformed, false)
    }

    func testSecondaryLayerMapsWheelClick() throws {
        let profile = Profile(
            id: "selected-synthetic-device",
            device: DeviceMatch(reference: "synthetic-vmd"),
            secondaryLayerControl: .lowerThumb,
            mappings: [ButtonMapping(control: .wheelClick, phase: .down, layer: .secondary, action: MappingAction(kind: .systemAction, value: "mission-control"))]
        )
        var engine = try RuleEngine(configuration: configuration(profiles: [profile]))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        let intent = try engine.process(button(.wheelClick, .down, at: 2))
        XCTAssertEqual(intent.first?.kind, .systemAction)
        XCTAssertEqual(intent.first?.value, "mission-control")
    }

    func testDuplicatePressAndMissingReleaseAreRecovered() throws {
        var engine = try RuleEngine(configuration: configuration(timeout: 10))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        let duplicate = try engine.process(button(.lowerThumb, .down, at: 2))
        XCTAssertEqual(duplicate.first?.value, "duplicate-button-down")
        let recovered = try engine.process(scroll(.vertical, 1, at: 12))
        XCTAssertTrue(recovered.contains { $0.value == "recovered-missing-release" && $0.control == .lowerThumb })
        XCTAssertEqual(recovered.last?.axis, .vertical)
        XCTAssertEqual(recovered.last?.transformed, false)
    }

    func testApplicationProfileTakesPriorityAndClearsHeldChord() throws {
        let base = Profile(id: "base", device: DeviceMatch(reference: "synthetic-vmd"), secondaryLayerControl: .lowerThumb, thumbWheelBehavior: .convertVerticalToHorizontal)
        let browser = Profile(
            id: "browser",
            priority: 10,
            device: DeviceMatch(reference: "synthetic-vmd"),
            applicationBundleIDs: ["com.example.browser"],
            thumbWheelBehavior: .preserveHostAxes,
            scroll: ScrollOptions(verticalMultiplier: 2)
        )
        var engine = try RuleEngine(configuration: configuration(profiles: [base, browser]))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        let profileChange = try engine.process(InputEvent(timestampMicros: 2, device: device, kind: .applicationActivated, applicationBundleID: "com.example.browser"))
        XCTAssertEqual(profileChange.last?.kind, .reset)
        let intents = try engine.process(scroll(.vertical, 3, at: 3))
        XCTAssertEqual(intents.first?.axis, .vertical)
        XCTAssertEqual(intents.first?.delta, 6)
    }

    func testUnselectedDeviceIsIgnored() throws {
        var engine = try RuleEngine(configuration: configuration())
        let other = DeviceIdentity(reference: "other-mouse")
        let intents = try engine.process(InputEvent(timestampMicros: 1, device: other, kind: .hostScroll, axis: .vertical, delta: 1))
        XCTAssertEqual(intents, [ActionIntent(timestampMicros: 1, kind: .diagnostic, value: "ignored-unselected-device")])
    }

    func testRawHIDIsNotInterpretedAsButton() throws {
        var engine = try RuleEngine(configuration: configuration())
        let event = InputEvent(timestampMicros: 1, device: device, kind: .rawHID, rawHID: RawHIDValue(reportID: 1, usagePage: 9, usage: 6, value: 1))
        let intents = try engine.process(event)
        XCTAssertEqual(intents.first?.value, "raw-hid-observed-not-interpreted")
        XCTAssertTrue(engine.heldControlSnapshot.isEmpty)
    }

    func testFixtureLoadsAndReplaysAsSyntheticOnly() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/synthetic-vmd-demo.json")
        let fixture = try FixtureReplay.load(from: fixtureURL)
        XCTAssertEqual(fixture.source, .synthetic)
        let intents = try FixtureReplay.replay(fixture)
        XCTAssertTrue(intents.contains { $0.kind == .scroll && $0.axis == .horizontal && $0.transformed == true })
        XCTAssertTrue(intents.contains { $0.kind == .scroll && $0.axis == .vertical && $0.delta == 6 })
    }

    func testMalformedConfigurationAndEventsAreRejected() throws {
        XCTAssertNoThrow(try configuration().validate())
        var malformed = configuration()
        malformed.schemaVersion = 2
        XCTAssertThrowsError(try malformed.validate())
        let incomplete = InputEvent(timestampMicros: 1, device: device, kind: .hostScroll)
        XCTAssertThrowsError(try incomplete.validate())
    }
}
