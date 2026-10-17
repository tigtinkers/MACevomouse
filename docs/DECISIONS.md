# Engineering decisions

Updated October 16, 2026. Each entry separates validated software behavior from
hardware and macOS claims.

## D-001 — Foundation-only Swift Package Manager core

- **Status:** CONFIRMED (source architecture); Linux execution pending a local Swift toolchain.
- **Decision:** Use a dependency-free SwiftPM package with `MACEvoCore` and a `macevo-cli` executable. The core imports only Foundation and has no native macOS targets in Milestone 1.
- **Why:** It keeps rule/configuration behavior testable on Linux and directly importable into a future Xcode workspace without FFI or duplicate models.
- **Tradeoff:** It cannot enumerate VMD hardware, assign macOS permissions, or inject input. That is intentionally deferred to a physically tested Mac phase.

## D-002 — Model physical labels as guided claims, not HID facts

- **Status:** CONFIRMED (model design); VMD label-to-HID mapping UNKNOWN.
- **Decision:** `topFinger`, `middleFinger`, `bottomFinger`, `wheelClick`, `upperThumb`, and `lowerThumb` are abstract, guided labels. `raw-hid` is an independent event kind containing report/usage/value data.
- **Why:** HID button bit/usage values do not establish physical location. The core does not translate a raw report into a button mapping.

## D-003 — Intent-only action boundary

- **Status:** CONFIRMED (source behavior).
- **Decision:** The rules engine emits serializable pass-through, shortcut, system-action, scroll, reset, and diagnostic intents. The CLI only prints them.
- **Why:** This prevents Linux simulator output from being confused with event injection and gives a future native adapter a narrow, testable contract.

## D-004 — Conservative lower-thumb scrolling policy

- **Status:** CONFIRMED (synthetic rule); VMD lower-thumb behavior UNKNOWN.
- **Decision:** When the abstract `lowerThumb` is held, profiles may convert *vertical* host scroll into horizontal intents. Existing horizontal input is preserved. Release, profile change, disconnect, and stale-hold recovery clear chord state.
- **Why:** It exercises the desired user experience without double-rotating a host axis or claiming a VMD report exists.

## D-005 — Profile selection by explicit device and app conditions

- **Status:** CONFIRMED (synthetic rule); macOS source attribution UNKNOWN.
- **Decision:** A profile can match a redacted logical device reference plus optional VID/PID and application bundle IDs. The highest priority matching profile wins; unmatched input is ignored by the simulator.
- **Why:** Future native code must prove that the event belongs to the selected VMD before altering it. A profile change clears held state to avoid a stuck modifier/chord.

## D-006 — Do not fork LinearMouse before M2 evidence

- **Status:** INFERRED from upstream documentation, checked October 16, 2026.
- **Decision:** Keep this independent, small core for M1; do not copy upstream code or commit to a fork. Reassess after VMD raw/translated event and source-attribution evidence on macOS.
- **Why:** Current LinearMouse is active, Swift, MIT-licensed, and documents per-device schemes, app conditions, button debouncing, and scroll controls. It may be a valuable M2 baseline, but it does not establish VMD six-control or source-specific suppression support. A fork now would create maintenance and licensing obligations before the feasibility gate.
- **License:** No LinearMouse or Mac Mouse Fix source was incorporated.

## M2 decision gate

Choose configure/extend LinearMouse, contribute upstream, or continue the standalone native adapter only after the Mac action matrix proves selected-device identity, all relevant collections, lower-thumb behavior, native-axis behavior, and safe suppression without impacting other mice.
