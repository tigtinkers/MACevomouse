# First Codex task — Linux-first implementation (copy as prompt)

You are starting the `tigtinkers/MACevomouse` repository. Read README.md, AGENTS.md and **all** docs/*.md before making changes.

## Context

I own an **Evoluent VerticalMouse D (VMD)** connected over USB. I want a polished, robust **macOS** tool that makes its six physical buttons useful and programmable, restores its lower-thumb-button + wheel horizontal scrolling, supports normal vertical scrolling, per-app mappings, button layers, and useful macOS shortcuts. Evoluent no longer supplies Mac Mouse Manager. Do not assume we know the mouse's HID mappings or whether the lower thumb is visible as an independent button.

**Development is on a Linux computer right now; a Mac with Xcode and the physical mouse will be available later.** Develop what we can genuinely run and test now, while shaping the architecture for native Mac integration. Do not claim to have run Xcode or hardware testing on a Mac.

## Your mission — Milestone 1

Take ownership as a pragmatic, inventive senior systems/macOS engineer. Research, challenge assumptions and choose the simplest viable foundations. The docs reflect current thinking, not orders to cargo-cult. You may change architecture or improve project organization if you document the reasoning and risks.

1. Inspect the repository and Linux environment. Determine whether `swift` or Docker is installed and available, and whether the physical Evoluent mouse is connected. Do not infer availability.
2. Review official Evoluent support and the MIT-licensed LinearMouse project, and briefly assess whether an upstream extension/fork might be preferable after hardware diagnostics. Respect licensing, particularly Mac Mouse Fix 3's different terms. Add helpful research discoveries to docs.
3. **Prefer a Linux-buildable Swift Package Manager project** with a Foundation-only event/rules/profile core and CLI. It should later be importable by SwiftUI/IOKit code in Xcode. If you find a better long-term solution, choose it and explain why, but avoid unnecessary FFI or heavyweight abstractions.
4. Design typed, versioned JSON models for device identity (including unknown IDs), input events (raw HID and translated host layers kept distinct), physical-button labels from guided confirmation, scrolling axes/deltas, application profiles, configurable triggers/secondary layers and output **intents**.
5. Implement a deterministic stateful engine supporting default/pass-through, button press/release, lower-thumb held + wheel horizontal conversion, release to normal vertical scrolling, optional secondary mapping and per-app rule selection. The thumb-and-wheel behavior here is **simulated** and must not be advertised as verified VMD hardware behavior. Avoid double conversion if an event is already horizontal.
6. Create `macevo-cli` (or a clear alternative) to replay JSON capture fixtures and print event and action-intent traces; include errors/validation and a concise `--help`. Do not inject mouse/keyboard events into Linux.
7. Add clearly labeled **synthetic** fixtures plus robust unit tests: all six abstract buttons, ordinary vertical scrolling, button+wheel horizontal conversion, wheel already horizontal, release/timeout, repeated press, lost release, app switch, source-device filtering and malformed config handling.
8. Optionally add a **read-only Linux HID diagnostic** if the physical VMD is actually connected, following docs/HARDWARE_DIAGNOSTICS.md. If absent or permissions lack, do not invent results. No exclusive grabs, system driver changes, firmware writes, device-wide keylogging or secret/serial capture.
9. Set up a sensible GitHub Actions CI workflow for Linux Swift build and tests. You may add a macOS **compile-only** workflow if warranted by working sources; do not conflate CI compilation with macOS runtime / HID compatibility.
10. Create or update `docs/HID_FINDINGS.md` and `docs/DECISIONS.md` to log evidence, open questions, design alternatives, and a precise checklist for the eventual Mac/Xcode phase.
11. Document setup, exact commands, fixture formats, expected CLI output, limitations and what remains untested in README and the relevant docs. Include a clear on-Mac first-session plan (`hidutil list`, interface capture, manual button trials, permission review, event source / suppression feasibility).

## Delivery criteria

- A coherent repository structure and running Linux-supported core/CLI (if toolchain available).
- `swift build` and `swift test` or an equally justified portable toolchain; show exact real results, not an invented pass.
- Synthetic fixtures and tests are unmistakably marked as simulated.
- Native Mac-only code is isolated to Mac-only targets or postponed; no unconditional IOKit/AppKit/SwiftUI import that breaks Linux.
- No default-user desktop input interception, root requirement, kernel/DriverKit extension, external telemetry or firmware modification.
- No unsupported assertion that all six buttons can be remapped on macOS.
- A concise final engineering report: files created/changed, tests executed, findings/evidence, important architectural decisions, unresolved uncertainties and exactly what to do when the Mac arrives.

## Engineering independence

Be creative and decisive. Compare realistic alternatives, inspect upstream source, and adjust the suggested file structure when you see a better design. Be practical; implement usable code rather than only more documentation. Do not block on the lack of a Mac, do not fabricate results, and do not over-engineer a custom driver before proving that a user-space tool is insufficient.

Commit changes on a purpose-named feature branch and open a PR for review rather than pushing directly into main. This first task ends at the Linux-testable foundation; follow-on Mac integration is separate.
