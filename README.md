# MACevomouse

A community-oriented, Evoluent-specific macOS mouse customization project, initially targeting the **Evoluent VerticalMouse D (VMD) connected by USB**.

**Status (October 2026): Research and pre-implementation. No physical VMD HID traces or macOS driver behavior have yet been verified.**

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

## Attribution

This is an independent project and is not affiliated with Evoluent. Other open-source projects are **references**, not automatic dependencies. Respect each upstream license; especially do not copy Mac Mouse Fix 3 code without reviewing its distinct license.

## Sources

Official Evoluent: https://evoluent.com/support/ and https://evoluent.com/support/download/ .
