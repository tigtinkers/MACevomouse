# Instructions for Codex and coding agents

## Mission

Develop `MACevomouse` as a robust, maintainable macOS enhancement for the USB Evoluent VerticalMouse D, starting on a Linux workstation. The user wants practical results and expects the agent to investigate intelligently, challenge weak assumptions, and make good technical choices. You have latitude to experiment, redesign the architecture, and propose alternatives; explain why a deviation is better.

**Read all of README.md and docs/*.md before coding.**

## Operating assumptions

- Current environment: Linux, probably without the physical VMD connected. Inspect, do not assume.
- Future environment: Mac with Xcode and physical VMD for HID, event-tap, TCC permissions and user-interaction testing.
- We can create a cross-platform core and CLI today; macOS SwiftUI / IOKit / CoreGraphics APIs cannot run on Linux.
- Cross-compilation, CI builds and mocks are *not* hardware validation.
- No verified VID/PID or button usage mapping exists yet. Never fabricate IDs or claim to have observed raw HID output.
- VMD comes in wired and wireless-USB variants. User says USB; exact wired-vs-receiver hardware may require observing the physical connection.
- Linux evdev codes and the macOS CGEvent/HID interpretation may differ. Correlate, do not equate.

## Engineering guidance (prefer, not dogma)

1. Prefer **Swift Package Manager** for the cross-platform event/rule/configuration engine and CLI; use `Foundation` and platform-independent files. Swift is officially supported on Linux and macOS. Keep native `AppKit`, `SwiftUI`, `IOKit` and `CoreGraphics` behind separately compiled macOS adapters.
2. If a different language/framework materially improves safety, performance, portability or access to USB/HID, choose it and document tradeoffs. Avoid a gratuitous dual-language FFI bridge in milestone one.
3. Build separate layers: normalized HID/input events → device identity → stateful modifier/chord recognizer → profile/rule resolver → output *intents* (do not inject real OS events on Linux).
4. Provide fake/mock adapters and deterministic JSON fixture playback. Separate assertions about simulated events from findings based on actual hardware.
5. Explicit button-to-physical-location labeling requires guided manual confirmation. USB usage/button number does *not* inherently tell us the physical control.
6. Raw HID input and host-translated events must be recorded separately, including input device/interface and report ID when available.
7. Privacy: no background keyboard logging; no collecting events from unrelated devices; avoid storing serial numbers. Captures must be explicit, short and redacted before commit.
8. Safety: first build should be passive/no device seize/no firmware write/no virtual HID/no event injection. On Mac, eventual remapping must feature immediate disable, passthrough fallback, protection against re-injection loops, graceful disconnect/reconnect, and unaffected trackpad/other mice.
9. Test edge cases: ordered down/up, hold+wheel chord, no-chord wheel, short press vs hold, release during scroll, duplicate press, missing release, app/profile switch during hold, unplug mid-gesture, competing modifiers, event-order races, scroll sign/axis and unit normalization.
10. Avoid dependencies that unnecessarily increase installation/signing/permission complexity; compare borrowing LinearMouse (MIT) against an independent adapter before committing to a fork.
11. Document every experiment. Maintain `docs/DECISIONS.md` and `docs/HID_FINDINGS.md` when work begins; mark each claim `CONFIRMED`, `INFERRED`, or `UNKNOWN`.
12. Preserve source licensing and credits. LinearMouse is MIT; Mac Mouse Fix 3 uses a different license. Other repos have their own terms.
13. Plan for accessible UI and no needless permissions. No root/system extension/DriverKit unless concrete evidence justifies it.
14. Favor clear incremental commits, easy inspection, small modules and useful README commands.

## Linux-first execution instructions

- Inspect `uname -a`, `cat /etc/os-release`, `command -v swift`, `swift --version`, `command -v docker`; use an installed toolchain or the official Swift Docker image as appropriate.
- If the toolchain cannot run, still build source/docs/tests; report the blocker accurately.
- Implement an executable CLI accepting fixture input and producing normalized events plus action intentions, not actual mouse/keyboard events.
- Include example fixtures with labels **synthetic**, alongside clear schemas and deterministic tests.
- Add GitHub Actions Linux `swift build` + `swift test`; optional macOS compilation job only if it adds value and is configured correctly.
- USB Linux inspection is optional and gated on actual device availability and user permissions; follow docs/HARDWARE_DIAGNOSTICS.md.

## Later macOS requirements

- First run `hidutil list` and obtain real model VID/PID and collections.
- Compare macOS events with Linux traces where possible.
- Use `IOHIDManager`/CoreHID after API availability review for enumeration/monitoring; `CGEventTap` and `CGEventCreateScrollWheelEvent` only when justified by permission and reliability tests.
- Selectively remap exactly one chosen Evoluent device; do not break normal pointer behavior.
- Verify all six controls and the lower-thumb + wheel path *on actual hardware* before advertising full compatibility.
- Use Xcode, signing, notarization and update mechanisms in a later milestone.

## Autonomous decision making

You are authorized to research upstream source, run tools available in your environment, improve file layout, implement working code, add tests and refine the product spec. Do not stop to ask minor questions if a safe assumption makes forward progress possible. Be specific about unverified results; present a concise test/evidence report and any decisions or unresolved questions.

Start with the assignment in docs/CODEX_KICKOFF.md.
