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

## D-007 — Ignore late events conservatively

- **Status:** CONFIRMED (synthetic rule).
- **Decision:** Reject a host event whose timestamp is older than the last accepted event, emitting a diagnostic intent without changing held-button state.
- **Why:** Applying a late press/release or scroll can fabricate a chord, resurrect a released button, or leave a mapping latched. A native adapter must deliver a monotonic, per-selected-device stream and separately surface any ordering failure.

## M2 decision gate

Choose configure/extend LinearMouse, contribute upstream, or continue the standalone native adapter only after the Mac action matrix proves selected-device identity, all relevant collections, lower-thumb behavior, native-axis behavior, and safe suppression without impacting other mice.

## D-008 — Mac passive preparation

- **CONFIRMED:** The portable engine binds to the first matching logical device until disconnect; profiles require a nonempty device reference. Passthrough releases follow their press and one-shot actions do not emit an unmatched release. Reset intents require an eventual adapter to release owned outputs. Up-phase mappings are rejected.
- **CONFIRMED:** A macOS-only experimental inspector enumerates HID devices and offers a bounded, selected-interface raw capture; it has no event tap or injection.
- **UNKNOWN:** Device enumeration, capture permissions, hotplug and VMD reports on physical hardware; translated-event attribution and suppression remain unproven.
- **CONFIRMED:** Timeout is disabled by default (`0`); nonzero values remain available for synthetic experiments and may interrupt a valid hold. No adapter currently consumes reset intents.
- **CONFIRMED:** A disabled-by-default synthetic session rejects physical input and emits a reset on disable; it is not a live event adapter.

## D-009 — Exact sender attribution for the wheel-click experiment

- **CONFIRMED (source review):** Reviewed LinearMouse commit `93d38f1981427fde98ceca105c794dae32c58b7e`; it obtains HID sender IDs from CGEvents through undocumented `CGEventCopyIOHIDEvent` and `IOHIDEventGetSenderID`. See `ThirdParty/README.md` for pinned sources and MIT notice.
- **Decision:** Keep our independent adapter, dynamically resolve the two optional symbols in a small macOS-only C boundary, and require a nonzero sender ID exactly equal to the explicitly selected interface's registry entry ID. Never use timing guesses or last-active-device fallback. Missing symbols or mismatched identity means no interception.
- **CONFIRMED (source/build):** The functions resolve on this host. A bounded listen-only probe precedes an explicitly enabled wheel-click experiment. Only host button 4 is eligible; keyboard output is a complete one-shot pair. Native scrolling and other controls are not intercepted.
- **UNKNOWN:** Actual sender matching, suppression, permissions, output delivery, hotplug/session recovery and second-device isolation on this hardware. Symbol presence and mocks do not establish compatibility.
- **Decision:** The extra native bridge is justified by M3 source attribution needs; the portable M1 core remains Foundation-only and has no native imports or FFI. Full button remapping stays deferred until this wheel-click experiment passes.

## D-010 — Saved shortcut MVP

- **CONFIRMED (automated tests):** Canonical typed shortcuts, validated atomic profile storage, lossless supported legacy-string migration, synthetic routing isolation and tagged keyboard pair construction are tested. Failed validation never overwrites the saved profile.
- **Decision:** Store a separate versioned shortcut profile for observed VID/PID 6780:401. Preserve lower thumb's native chord. Dictation is a user-confirmed configured shortcut, not a hardcoded Fn behavior or a direct dictation API.
- **UNKNOWN:** The complete physical model, future device variants, actual Dictation operation and all runtime remapping acceptance cases.
