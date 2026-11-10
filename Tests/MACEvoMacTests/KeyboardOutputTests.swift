import XCTest
import MACEvoCore
@testable import MACEvoInspector

final class KeyboardOutputTests: XCTestCase {
    @MainActor func testEverySupportedKeyProducesATaggedDownUpPairWithoutPosting() throws {
        XCTAssertEqual(Set(LiveShortcutAdapter.keyCodes.keys), KeyboardShortcut.supportedKeys)
        for key in KeyboardShortcut.supportedKeys {
            let shortcut = try KeyboardShortcut(text: "command+control+option+shift+\(key)")
            let events = try XCTUnwrap(LiveShortcutAdapter.makeEvents(shortcut))
            XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])
            XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, Array(repeating: Int64(LiveShortcutAdapter.keyCodes[key]!), count: 2))
            for event in events {
                XCTAssertEqual(event.flags, [.maskCommand, .maskControl, .maskAlternate, .maskShift])
                XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), LiveShortcutAdapter.marker)
            }
        }
    }
}
