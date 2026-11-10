import XCTest
@testable import MACEvoCore

final class ShortcutTests: XCTestCase {
    func testShortcutNormalizationAndValidation() throws {
        XCTAssertEqual(try KeyboardShortcut(text: " Shift + COMMAND + z ").text, "command+shift+z")
        for invalid in ["", "command", "fn+f1", "command+command+a", "command++a", "command+a+b", "option+unsupported"] {
            XCTAssertThrowsError(try KeyboardShortcut(text: invalid), invalid)
        }
        let invalidJSON = Data(#"{"modifiers":["command","command"],"key":"a"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(KeyboardShortcut.self, from: invalidJSON).validate())
    }
    func testProfileRoundTripAndReservedControl() throws {
        let profile = ShortcutProfile(bindings: [ShortcutBinding(control: .wheelClick, shortcut: try KeyboardShortcut(text: "control+shift+d"), isDictation: true)])
        XCTAssertEqual(try ShortcutProfile.decode(JSONEncoder().encode(profile)), profile)
        XCTAssertThrowsError(try ShortcutProfile(bindings: [ShortcutBinding(control: .lowerThumb, shortcut: try KeyboardShortcut(text: "a"))]).validate())
        var duplicate = profile; duplicate.bindings += profile.bindings
        XCTAssertThrowsError(try duplicate.validate())
    }
    func testStorePreservesLastValidSettingsOnFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var store = ShortcutProfileStore(url: root.appendingPathComponent("settings.json"))
        let profile = ShortcutProfile(bindings: [ShortcutBinding(control: .wheelClick, shortcut: try KeyboardShortcut(text: "command+a"))])
        try store.save(profile)
        var reloaded = ShortcutProfileStore(url: store.url); try reloaded.load()
        XCTAssertEqual(reloaded.current, profile)
        try Data("broken".utf8).write(to: store.url)
        XCTAssertThrowsError(try store.load()); XCTAssertEqual(store.current, profile)
        var invalid = profile; invalid.schemaVersion = 9
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(try String(contentsOf: store.url), "broken")
    }
    func testLegacyMigrationRejectsLossyImport() throws {
        let mapping = ButtonMapping(control: .wheelClick, phase: .down, action: MappingAction(kind: .shortcut, value: "shift+command+a"))
        let legacy = MACEvoConfiguration(profiles: [Profile(id: "legacy", device: DeviceMatch(reference: "observed", vendorID: 0x1a7c, productID: 0x0191), mappings: [mapping])])
        let imported = try ShortcutProfile.decode(JSONEncoder().encode(legacy))
        XCTAssertEqual(imported.bindings.first?.shortcut.text, "command+shift+a")
        var invalid = legacy; invalid.profiles[0].thumbWheelBehavior = .convertVerticalToHorizontal
        XCTAssertThrowsError(try ShortcutProfile.decode(JSONEncoder().encode(invalid)))
    }
    func testRouterIsolationDuplicatePressAndRecovery() throws {
        let shortcut = try KeyboardShortcut(text: "command+shift+d")
        var router = ShortcutRouter()
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down), .passthrough)
        try router.prepare(sender: 1, shortcut: shortcut); router.enable()
        XCTAssertEqual(router.route(sender: 2, button: 4, phase: .down), .passthrough)
        XCTAssertEqual(router.route(sender: 0, button: 4, phase: .down), .passthrough)
        XCTAssertEqual(router.route(sender: 1, button: 0, phase: .down), .passthrough)
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down, generated: true), .passthrough)
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down), .fire(shortcut))
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down), .suppress)
        XCTAssertEqual(router.route(sender: 2, button: 4, phase: .up), .passthrough)
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .up), .suppress)
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .up), .passthrough)
        router.disable(fault: true)
        XCTAssertEqual(router.state, .faulted)
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down), .passthrough)
        try router.prepare(sender: 1, shortcut: shortcut); router.enable()
        XCTAssertEqual(router.route(sender: 1, button: 4, phase: .down), .fire(shortcut))
    }
    func testCaptureIgnoresStaleDataAndDoesNotDropRepeatedWheelTicks() {
        let document = RawCaptureDocument(trial: "synthetic buffer test", vendorID: 0, productID: 0, includeMovement: false)
        var buffer = RawCaptureBuffer(document: document, startTicks: 1000, timebaseNumerator: 125, timebaseDenominator: 3, capacity: 3)
        let wheel = RawHIDValue(reportID: 0, usagePage: 1, usage: 56, value: 1)
        XCTAssertNil(buffer.append(wheel, elementID: 1, ticks: 900))
        XCTAssertEqual(buffer.append(wheel, elementID: 1, ticks: 1024)?.elapsedMicros, 1)
        XCTAssertNil(buffer.append(wheel, elementID: 1, ticks: 1024))
        XCTAssertNotNil(buffer.append(wheel, elementID: 1, ticks: 1048))
        XCTAssertNotNil(buffer.append(wheel, elementID: 1, ticks: 1072))
        XCTAssertNil(buffer.append(wheel, elementID: 1, ticks: 1096))
        XCTAssertEqual(buffer.document.omittedValues, 1)
        XCTAssertNil(buffer.append(RawHIDValue(usagePage: 7, usage: 4, value: 1), elementID: 9, ticks: 1100))
        XCTAssertEqual(buffer.document.records.count, 3)
    }
}
