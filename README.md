# MACevomouse

A community-oriented, Evoluent-specific macOS mouse customization project, initially targeting the **Evoluent VerticalMouse D (VMD) connected by USB**.

**Status (November 9, 2026): Six physical button usages and both native scroll paths have been observed on a mouse reporting “Evoluent VerticalMouse 4” (6780:401). Saved shortcut editing and an experimental wheel-click adapter are implemented; live routing and suppression require the next physical test.**

## Goal

Restore and extend functionality that Evoluent's discontinued Mac Mouse Manager no longer provides: independently programmable mouse controls, reliable vertical and horizontal scrolling (especially the lower-thumb-button + wheel chord), application-specific profiles, shortcuts, and secondary button layers.

The product target is a **native macOS configuration app and user-space input service**, not necessarily a kernel or DriverKit driver. The built-in macOS USB HID mouse stack already handles basic pointing.

## Development history: Linux first

The original M1 development machine was Linux. The project is now being prepared on a Mac; the connected mouse has reported a different product name, with user-labeled HID observations recorded in the findings log. Linux remains a supported platform for the portable core.

Build **portable, testable foundations now**, and introduce the macOS hardware adapter when a Mac becomes available:

1. Inspect the existing documentation and source references.
2. Implement a cross-platform domain model / event engine / configuration schema / replay CLI with tests.
3. On Linux, optionally collect **passive** USB/HID/evdev traces from the VMD if the physical device is available. Never assume it is connected.
4. Build on Linux using Swift Package Manager (or justify a different portable approach), plus optional GitHub Actions macOS compile checks.
5. Later, use Xcode on the Mac to build the SwiftUI app, enumerate real HID interfaces, inspect device events, integrate safe remapping, and test permissions/signing/distribution.

Do **not** claim Linux validation proves anything about macOS HID behavior. Do **not** imply that an Xcode project or native app has been run just because its shared logic builds on Linux.

## Read these documents in order

- [AGENTS.md](AGENTS.md) — instructions for Codex and other coding agents
- [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) — user goals, controls, features, product scope and unknowns
- [docs/RESEARCH.md](docs/RESEARCH.md) — official documentation, open-source precedents, API and licensing notes
- [docs/HARDWARE_DIAGNOSTICS.md](docs/HARDWARE_DIAGNOSTICS.md) — passive Linux and future Mac test plans, evidence format
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — proposed components, safety, milestones, release maintenance
- [docs/CODEX_KICKOFF.md](docs/CODEX_KICKOFF.md) — copyable first implementation assignment

## Definition of early success

A reproducible `swift build` / `swift test` (or documented justified alternative) on Linux; well-tested event/chord/profile/scroll logic; redacted sample fixtures; a usable fixture-replay CLI; and Mac-specific integration seams without pretending to have seen actual VMD hardware reports.

## Milestone 1: build and replay

The Swift package deliberately contains only Foundation-based model, configuration,
rule, fixture-replay, and CLI code. It contains no IOKit, AppKit, SwiftUI, event
tap, event injection, device seize, firmware, or privileged code.

On a machine with Swift 5.9 or newer:

```bash
swift build --build-tests
swift test
swift run macevo-cli validate Fixtures/synthetic-vmd-demo.json
swift run macevo-cli replay Fixtures/synthetic-vmd-demo.json
```

`macevo-cli replay` emits one JSON action *intent* per line. It does not post a
mouse, keyboard, scroll, or system event. The included fixture is marked
`source: "synthetic"`, uses abstract physical-location labels, and is not a VMD
capture. The CLI rejects non-synthetic fixture sources so it cannot be mistaken
for a hardware collector.

Linux CI installs Swift and runs those commands on every pull request and push to `main`. A macOS CI job builds and tests the native target. The historical Linux inventory is recorded in `docs/HID_FINDINGS.md`.

## Fixture and configuration format

`Fixtures/synthetic-vmd-demo.json` is the executable format example. A fixture
contains a version, required label/source, a versioned configuration, and ordered
events. Its `raw-hid` records carry report/usage/value data separately from
`host-button` and `host-scroll` records. A raw usage is logged as an observation,
never silently interpreted as one of the six labels.

`DeviceIdentity.reference` is a redacted logical adapter reference. VID/PID are
optional numeric fields and must remain absent until a physical descriptor is
observed. Profiles select an explicit device match, optional application bundle
IDs, mappings, an optional secondary-layer control, scroll options, and a
thumb-wheel policy. `convert-vertical-to-horizontal` is a **synthetic software
policy**, not a claim that lower thumb produces a readable VMD event. Native
horizontal input is always preserved rather than transformed a second time.

## Local shortcut app

Build the local app with `Scripts/build-app.sh`, then open `.build/MACevomouse.app`. The **Assignments** tab saves validated shortcuts and offers a focused recorder and a user-confirmed Dictation shortcut label. Lower thumb stays reserved for native scrolling. Only wheel click has an experimental live path: it requires a successful selected-device probe and explicit enablement, and starts disabled at launch. Other assignments are saved but not executed yet.

Follow [the MVP testing guide](docs/MVP_TESTING.md) for permissions, the harmless first shortcut, disable/recovery tests, known limitations and profile storage. No live remapping was activated during automated testing. The optional attribution functions are undocumented macOS APIs, isolated behind runtime capability checks; see [upstream review and attribution](ThirdParty/README.md).

## Passive Mac inspector (experimental)

On macOS with Swift and Xcode installed, run `swift run macevo-inspector`. Refresh the device list, explicitly select the intended HID interface, then start a raw-value capture. A three-second countdown precedes the ten-second capture; wait for “Recording” before acting. Stop at any time and use Copy Results to share the output. Pointer X/Y movement is hidden by default and can be included when needed. Values are displayed in memory only, limited to generic-desktop and button usage pages, with no serial numbers. Do not select a keyboard or type during capture. An interface may be missing or inaccessible; this tool does not establish VMD identity or capture translated host events. It does not seize devices, suppress input or inject events. Physical testing, permissions, hotplug behavior and device attribution remain unverified.

The **Assignment preview** tab is an in-memory mockup for the six unconfirmed control labels. Select a control, choose a default, keyboard chord, Mac action, or disabled assignment, and use the simulation buttons to see intents from the real portable rule engine. A lower-thumb secondary layer and wheel chord can also be explored. Shortcut text is not validated or recorded from keys, changes are not saved, and no action is sent to macOS. This preview does not prove that a physical button is observable or programmable.

Before the first physical session, connect a second pointing device if available, run `hidutil list`, connect the VMD and compare the list, then select only the identified VMD interface in **Hardware trials**. Choose one labeled trial and capture a short window. New captures show relative microseconds using the platform timebase and exclude values older than capture start. **Export JSON** saves a redacted diagnostic document; host attribution probes remain separate. Repeat for each relevant interface and the T01–T14 matrix in `docs/HARDWARE_DIAGNOSTICS.md`. Keyboard usages and consumer usages other than AC Pan (page 12, usage 568) are intentionally excluded from this capture, so absence of a value is inconclusive. The experimental wheel-click adapter uses exact sender matching and disables on device removal; the raw inspector still refreshes its device list manually.

The simulator now requires a nonempty logical device reference on every profile. Button mappings are down-phase only: shortcuts and system actions are one-shot, while passthrough ups follow their downs. Reset intents mean an eventual adapter must release any outputs it owns. The default stale-hold timeout is disabled (`0`) so legitimate long holds remain active. A nonzero timeout is an explicit synthetic recovery option and can interrupt a valid hold. Existing fixtures retain their configured behavior. The `SimulationSession` is disabled by default, accepts synthetic events only, and returns a reset intent when disabled.

## First Mac session

1. Record `sw_vers`, `xcodebuild -version`, `hidutil list`, and a redacted
   before/after `system_profiler SPUSBDataType` comparison.
2. Build a passive, selected-device `IOHIDManager` inspector; record raw values,
   interfaces, report IDs, and translated host events in separate files.
3. Run the labelled T01–T14 physical action matrix in
   `docs/HARDWARE_DIAGNOSTICS.md`, including lower-thumb + wheel and reconnect.
4. Confirm source attribution and original-event suppression feasibility before
   enabling any remap. Add a one-click disable and pass-through fallback first.
5. Only then add isolated macOS targets for SwiftUI, IOKit/CoreHID, active-app
   observation, and carefully permission-gated event handling.

The full evidence and safety checklist is maintained in
`docs/HID_FINDINGS.md`; architecture choices are in `docs/DECISIONS.md`.

## Attribution

This is an independent project and is not affiliated with Evoluent. Other open-source projects are **references**, not automatic dependencies. Respect each upstream license; especially do not copy Mac Mouse Fix 3 code without reviewing its distinct license.

## Sources

Official Evoluent: https://evoluent.com/support/ and https://evoluent.com/support/download/ .
