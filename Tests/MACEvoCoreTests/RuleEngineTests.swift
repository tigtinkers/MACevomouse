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

    func testLateEventIsIgnoredRatherThanCreatingAFalseChord() throws {
        var engine = try RuleEngine(configuration: configuration())
        _ = try engine.process(button(.lowerThumb, .down, at: 20))
        let late = try engine.process(scroll(.vertical, 3, at: 10))
        XCTAssertEqual(late, [ActionIntent(timestampMicros: 10, kind: .diagnostic, value: "out-of-order-timestamp-ignored")])
        let current = try engine.process(scroll(.vertical, 3, at: 30))
        XCTAssertEqual(current.first?.axis, .horizontal)
        XCTAssertEqual(current.first?.transformed, true)
    }

    func testScrollSignAndScalingAreIndependentPerAxis() throws {
        let profile = Profile(
            id: "selected-synthetic-device",
            device: DeviceMatch(reference: "synthetic-vmd"),
            thumbWheelBehavior: .preserveHostAxes,
            scroll: ScrollOptions(verticalMultiplier: 0.5, horizontalMultiplier: 2, reverseVertical: true, reverseHorizontal: true)
        )
        var engine = try RuleEngine(configuration: configuration(profiles: [profile]))
        XCTAssertEqual(try engine.process(scroll(.vertical, 4, at: 1)).first?.delta, -2)
        XCTAssertEqual(try engine.process(scroll(.horizontal, 3, at: 2)).first?.delta, -6)
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
        malformed = configuration()
        malformed.profiles[0].scroll.verticalMultiplier = .infinity
        XCTAssertThrowsError(try malformed.validate())
        let incomplete = InputEvent(timestampMicros: 1, device: device, kind: .hostScroll)
        XCTAssertThrowsError(try incomplete.validate())
    }
    func testLayerChangeDoesNotChangePairedRelease() throws {
        let profile = Profile(id: "p", device: DeviceMatch(reference: "synthetic-vmd"), secondaryLayerControl: .lowerThumb,
            mappings: [ButtonMapping(control: .wheelClick, phase: .down, layer: .secondary, action: MappingAction(kind: .systemAction, value: "mission-control"))])
        var engine = try RuleEngine(configuration: configuration(profiles: [profile]))
        _ = try engine.process(button(.wheelClick, .down, at: 1))
        _ = try engine.process(button(.lowerThumb, .down, at: 2))
        let release = try engine.process(button(.wheelClick, .up, at: 3))
        XCTAssertEqual(release.first?.kind, .passThroughButton)
        XCTAssertEqual(release.first?.phase, .up)
    }

    func testOneShotMappingDoesNotEmitUnmatchedRelease() throws {
        let profile = Profile(id: "p", device: DeviceMatch(reference: "synthetic-vmd"), mappings: [ButtonMapping(control: .upperThumb, phase: .down, action: MappingAction(kind: .shortcut, value: "command+left"))])
        var engine = try RuleEngine(configuration: configuration(profiles: [profile]))
        XCTAssertEqual(try engine.process(button(.upperThumb, .down, at: 1)).first?.kind, .shortcut)
        XCTAssertTrue(try engine.process(button(.upperThumb, .up, at: 2)).isEmpty)
    }

    func testOtherDeviceCannotAdvanceClockOrRecoverHold() throws {
        let second = Profile(id: "other", device: DeviceMatch(reference: "other"))
        let first = Profile(id: "first", device: DeviceMatch(reference: "synthetic-vmd"), thumbWheelBehavior: .convertVerticalToHorizontal)
        var engine = try RuleEngine(configuration: configuration(timeout: 10, profiles: [first, second]))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        let other = InputEvent(timestampMicros: 100, device: DeviceIdentity(reference: "other"), kind: .hostScroll, axis: .vertical, delta: 1)
        XCTAssertEqual(try engine.process(other).first?.value, "ignored-unselected-device")
        XCTAssertEqual(try engine.process(scroll(.vertical, 1, at: 2)).first?.axis, .horizontal)
    }

    func testDisconnectResetsAndAllowsAnotherSelectedDevice() throws {
        let other = Profile(id: "other", device: DeviceMatch(reference: "other"))
        let first = Profile(id: "first", device: DeviceMatch(reference: "synthetic-vmd"))
        var engine = try RuleEngine(configuration: configuration(profiles: [first, other]))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        XCTAssertEqual(try engine.process(InputEvent(timestampMicros: 2, device: device, kind: .deviceDisconnected)).last?.kind, .reset)
        XCTAssertTrue(engine.heldControlSnapshot.isEmpty)
        let event = InputEvent(timestampMicros: 1, device: DeviceIdentity(reference: "other"), kind: .hostScroll, axis: .vertical, delta: 1)
        XCTAssertEqual(try engine.process(event).last?.kind, .scroll)
    }

    func testUnrestrictedAndDuplicateMappingsRejected() throws {
        XCTAssertThrowsError(try MACEvoConfiguration(profiles: [Profile(id: "all")]).validate())
        let mapping = ButtonMapping(control: .upperThumb, phase: .down, action: MappingAction(kind: .passThrough))
        let profile = Profile(id: "p", device: DeviceMatch(reference: "selected"), mappings: [mapping, mapping])
        XCTAssertThrowsError(try MACEvoConfiguration(profiles: [profile]).validate())
    }

    func testDefaultSettingsPreserveLongHold() throws {
        let profile = Profile(id: "p", device: DeviceMatch(reference: "synthetic-vmd"), thumbWheelBehavior: .convertVerticalToHorizontal)
        var engine = try RuleEngine(configuration: MACEvoConfiguration(profiles: [profile]))
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        XCTAssertEqual(try engine.process(scroll(.vertical, 1, at: 60_000_000)).last?.axis, .horizontal)
        XCTAssertEqual(try engine.process(button(.lowerThumb, .up, at: 60_000_001)).last?.phase, .up)
    }

    func testSimulationIsDisabledByDefaultAndResetsOnDisable() throws {
        var session = try SimulationSession(configuration: configuration())
        XCTAssertTrue(try session.process(button(.lowerThumb, .down, at: 1)).isEmpty)
        session.enable()
        XCTAssertEqual(try session.process(button(.lowerThumb, .down, at: 2)).first?.phase, .down)
        XCTAssertEqual(session.disable(at: 3).first?.value, "simulation-disabled")
        XCTAssertTrue(session.disable(at: 4).isEmpty)
        session.enable()
        XCTAssertEqual(try session.process(scroll(.vertical, 1, at: 5)).last?.axis, .vertical)
        let physical = InputEvent(source: .physicalMacOS, timestampMicros: 6, device: device, kind: .hostScroll, axis: .vertical, delta: 1)
        XCTAssertThrowsError(try session.process(physical))
    }

    func testDisconnectAfterSwitchToUnmatchedAppStillResets() throws {
        let profile = Profile(id: "app", device: DeviceMatch(reference: "synthetic-vmd"), applicationBundleIDs: ["app.one"])
        var engine = try RuleEngine(configuration: configuration(profiles: [profile]), activeApplicationBundleID: "app.one")
        _ = try engine.process(button(.lowerThumb, .down, at: 1))
        _ = try engine.process(InputEvent(timestampMicros: 2, device: device, kind: .applicationActivated, applicationBundleID: "app.two"))
        XCTAssertEqual(try engine.process(InputEvent(timestampMicros: 3, device: device, kind: .deviceDisconnected)).last?.value, "device-disconnected")
    }

}
