# Product brief — USB Evoluent VerticalMouse D on macOS

Updated: October 16, 2026. Target: `tigtinkers/MACevomouse`.

## Context / problem

The owner has an Evoluent VerticalMouse D (VMD), connected over USB, and wants it to be **fully functional on a Mac**, with all physical buttons programmable, its useful horizontal/vertical scrolling behavior, multiple software profiles and ergonomic controls. Evoluent no longer supplies a supported Mac Mouse Manager. The standard macOS mouse stack handles pointing and basic buttons, but the desired advanced functions are not guaranteed.

The current coding machine is Linux. Later there will be a Mac for Xcode, live macOS HID inspection, and manual QA. The project is **not** intended to be a Linux mouse customization tool; Linux is a pre-development/test workbench.

## Target users and desired experience

Primary: a technically engaged power user who wants the distinctive VMD hardware ergonomics and deep control under macOS with a pleasant native UI, not an intimidating driver installer.

Core design principles:
- Restore familiar VMD controls first; intelligently add Mac-centric features afterward.
- Every available physical button can be assigned independently when technically observable.
- Clear button diagrams, click-to-identify, easy capture of chords, and plain-English mappings.
- Per-app behavior including apps such as browsers, Finder, productivity apps, Xcode and 3D/CAD editors.
- Preserve natural pointer feel, predictable latency, and trackpad/other mouse behavior.
- Reliable, reversible changes: disable switch, reset to defaults, unobtrusive background service.
- Local-first privacy with minimal privileges.

## Hardware assumptions and evidence status

**Confirmed by user:** Evoluent VerticalMouse D, USB. We have **not** examined their hardware, cable vs receiver, USB descriptor, VID/PID, HID report descriptor, or host events.

Evoluent's documented VerticalMouse D/4 Windows-default physical layout is:
| Physical position | Manufacturer's Windows default without Mouse Manager | Diagnostic priority |
| --- | --- | --- |
| Top finger button (#1) | Primary / left click | Verify actual HID usage and press-release |
| Middle finger button (#2) | Middle click | Verify; important to CAD and browser navigation |
| Bottom finger button (#3) | Secondary / right click | Verify |
| Scroll wheel click (#4) | Forward navigation | Determine host event; wheel click is **not necessarily** middle click on VMD |
| Upper thumb button (#5) | Back navigation | Verify host event |
| Lower thumb button (#6) | Horizontal scroll *with wheel* | Critical: independent button, modifier, keyboard code, internal firmware operation, or none? |
| Wheel rotation | Vertical scrolling | Signed relative increments; test while #6 held |
| Hardware pointer-speed control | Changes hardware speed (lights) | Separate control, possibly firmware-only; no claim of programmable software DPI |

**Important distinction:** Evoluent's generic macOS default-button description specifically covers the top/middle/bottom buttons and says functions are fixed without third-party software. It does **not** establish that all controls expose six separately readable macOS button events.

Official sources: https://evoluent.com/support/ and https://evoluent.com/support/download/ .

## Desired capability matrix

| Capability | Priority | Evidence / qualification |
| --- | --- | --- |
| Identify and expose all six physical controls | P0 | Needs actual hardware capture |
| Safe per-button remapping, pass-through defaults | P0 | Depends on event capture / suppression |
| Original lower thumb + wheel horizontal scroll | P0 | Probe whether firmware already produces horizontal axis |
| Vertical wheel smoothness, speed, direction | P0 | Software, but macOS event fidelity to test |
| App-specific profiles / overrides | P1 | Software |
| Keyboard shortcuts, back/forward, desktop/mission control | P1 | OS actions/permissions to test |
| Secondary layer yielding up to nine assignments | P1 | Manufacturer Windows Manager documents up to nine; design flexible layers |
| Hold, double-click, long press, drag-lock/chords | P1 | Guard against missed releases and click lag |
| Mouse-only rules leaving trackpad alone | P1 | Accurate device attribution is an architectural risk |
| Custom horizontal mode / optional context-aware direction | P2 | Context detection can be ambiguous; make opt-in |
| Motion-to-scroll, horizontal/vertical gesture actions | P2 | Could be useful if native mouse doesn't expose modifier |
| DPI/sensor mode controlled from UI | P3 research | May be internal hardware setting; avoid promise |
| Update mechanism, diagnostics export and recovery | P1 | Packaging/maintenance later |

## Scrolling design choices

**A. Evoluent-compatible mode:** press-and-hold lower thumb; wheel deltas should become horizontal instead of vertical, release returns vertical behavior. However, if the device's firmware already emits horizontal deltas while #6 is held, **do not rotate them twice**. Distinguish raw HID vs translated wheel behavior.

**B. Software-configured mode:** optional Shift+wheel, other button+wheel chords, per-app defaults, user-selected axes and acceleration/smoothing.

**C. Smart mode (later):** attempt context-aware horizontal handling only with clear opt-in and deterministic fallback; user intent is not reliably inferrable from a generic scroll event.

Controls: independent horizontal/vertical speed, reverse, acceleration/inertia (within host API limitations), and passthrough when app ignores transformed events.

## Non-goals for first implementation

No custom kernel extension, firmware flashing, bootloader manipulation, Bluetooth support, paid service/cloud, telemetry, 3rd-party device interception, production-grade macOS distribution, and no claim of completed physical compatibility before live testing.

## Safety and privacy

- Restrict collection to explicitly selected Evoluent interfaces; allow an explicit short diagnostic session.
- Avoid capture of unrelated keyboard typing (even if VMD presents a composite keyboard interface).
- Do not expose or commit unique serial numbers; sanitize file paths, login names, precise device location IDs and sensitive application data in shared logs.
- Avoid seizing device or interfering with desktop input during diagnostics.
- Eventually expose an easy enable/disable switch and reset profile.
- Gracefully recover on device disconnect, app crash, sleep/wake, session switch and OS updates.
- OS accessibility/input permissions should be requested contextually with explanations.

## Acceptance criteria — eventual product

Demonstrate six control-by-control press/release tests; verified lower thumb + wheel operation; reproducible remapping with app profiles; other mice unaffected; a safe disable path; packaging and runtime stability after reboot and reconnect. Capture tested OS, app and hardware revision in a test matrix.

## Open questions

1. Exact VMD variant (VMDM / VMDS / VMDL and USB cable vs wireless receiver; do not block core work).
2. Actual VID/PID, collections, report descriptors and HID usages.
3. Whether lower-thumb sends an independent event or converts wheel reports in firmware.
4. Whether wheel click and thumbs are mouse usages, consumer controls or keyboard-like reports.
5. Whether hardware pointer-speed changes emit host reports.
6. macOS release/processor, available input permissions and event attribution.
7. Whether LinearMouse meets 80–90% of requirements with configuration before writing a separate engine.
8. Whether a user's required apps need unusual gesture handling.
