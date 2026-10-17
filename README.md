# MACevomouse

A community-oriented, Evoluent-specific macOS mouse customization project, initially targeting the **Evoluent VerticalMouse D (VMD) connected by USB**.

**Status (October 2026): Milestone 1 portable Swift core and synthetic replay are implemented. No physical VMD HID traces or macOS driver behavior have been verified.**

## Goal

Restore and extend functionality that Evoluent's discontinued Mac Mouse Manager no longer provides: independently programmable mouse controls, reliable vertical and horizontal scrolling (especially the lower-thumb-button + wheel chord), application-specific profiles, shortcuts, and secondary button layers.

The product target is a **native macOS configuration app and user-space input service**, not necessarily a kernel or DriverKit driver. The built-in macOS USB HID mouse stack already handles basic pointing.

## Crucial development constraint: Linux first, macOS later

The current developer machine is **Linux**. We **cannot locally run Xcode, SwiftUI, IOKit, or macOS input-event integration** on Linux. The eventual test machine will be a Mac with the physical Evoluent mouse.

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

Linux CI installs Swift and runs those commands on every pull request and push to
`main`. This development workstation currently has neither Swift nor Docker, so
local build/test results must not be inferred from the presence of source files;
see `docs/HID_FINDINGS.md` for the exact local evidence.

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
