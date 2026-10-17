# Research, sources, and prior design notes

Updated: October 16, 2026. This document distinguishes **official documentation**, **community implementations**, and **unverified hypotheses**. URLs are starting points for further research; upstream APIs/licensing may change.

## Manufacturer evidence

### Evoluent support
- https://evoluent.com/support/
  - Gives VMD / VerticalMouse 4 **Windows default**: top left, middle finger middle-click, bottom right, wheel-click forward, upper thumb back, lower thumb horizontal scroll with wheel.
  - Mac OS generic notes cover the primary three buttons and state Mouse Manager cannot customize them on Mac.
  - Describes hardware pointer speed adjustment and advises 1–2 indicator lights for precision.
  - USB devices plug in directly; avoid making a KVM/hub assumption; test direct USB if issues occur.
  - Documents occasional inadvertent double-click behavior: useful reason for diagnostic bounce counters.
- https://evoluent.com/support/download/
  - Windows Mouse Manager for VMD and VerticalMouse 4 (USB variants) v6.0.9.3 is listed as of the referenced page.
  - Features: reassign buttons, keyboard chords, **up to nine functions**, application-specific customization.
  - Mac Mouse Manager no longer provided: Evoluent reports difficulty with repeated Apple OS recertification.
  - Evoluent suggests Mac Mouse Fix **version 2.2.0**, not a blanket licensing recommendation for every later release.
- VMD comes in wired small/medium/large (VMDS/VMDM/VMDL) and wireless USB versions; user's exact wired subtype is not independently established.
- An independent distributor spec https://evoluent.ca/detailed_specification_pages/evoluent_evoluent_verticalmouse_d.html discusses lower thumb secondary functions and optional horizontal/brightness wheel functions; **manufacturer support page takes priority**. Distributor contains some self-inconsistent counts; treat nine as the manufacturer-stated target.

### Important correction to assumptions
- VMD **wheel click is listed as Forward** in Windows defaults; the middle finger button is listed as **Middle click**.
- The lower thumb's horizontal function is **modifier + wheel**, not proof of a dedicated second scroll sensor/axis or guaranteed independent button 6 usage on macOS.
- Distinguish "six physical buttons" from "six independently readable/reportable HID buttons". Needs capture.

## Open-source references (research before deciding whether to fork)

1. **LinearMouse:** https://github.com/linearmouse/linearmouse
   - Configuration reference: https://github.com/linearmouse/linearmouse/blob/main/Documentation/Configuration.md
   - MIT license: https://github.com/linearmouse/linearmouse/blob/main/LICENSE
   - Native macOS scrolling, per-device rules, app-specific schemes, structured button mappings, simultaneous/hold/wheel triggers, reverse scroll and smoothing. Highest-value upstream candidate for a fork, optional integration, or implementation patterns.
   - Do not blindly copy a whole app into this repo; isolate the parts we actually need and preserve MIT notices on incorporated code. Verify upstream version and real VMD compatibility later.
2. **Mac Mouse Fix:** https://github.com/noah-nuebling/mac-mouse-fix
   - Strong inspiration for gestures, scrolling and UX.
   - Mac Mouse Fix 2 is free; **Mac Mouse Fix 3+ uses a distinct MMF license** (see https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License and README), so do not treat it as generic MIT code. Check terms and take inspiration from behaviors rather than copying code unless compliant.
3. **Karabiner-Elements:** https://github.com/pqrs-org/Karabiner-Elements
   - Advanced event remapping and virtual HID patterns; far more infrastructure/permissions than first milestone needs. Useful only for escalation/design research.
4. **Historical Evoluent + Karabiner community example:** https://gist.github.com/patrickwelker/a4998af276b146f25121d1b991767bf0
   - VMD is **not** VM4. The gist is a clue about HID/button mapping, not verified VMD-compatible configuration.
5. **Linux HID tools:** https://gitlab.freedesktop.org/libevdev/hid-tools (hid-recorder, hid-decode, hid-replay); https://github.com/bentiss/hid-tools is a mirror/redirect.
   - Linux HID traces help identify descriptors and report patterns, but macOS mapping is still a separate investigation.

## Apple frameworks / documentation to assess on a Mac

- Apple HID terminal discovery: https://developer.apple.com/documentation/corehid/discoveringhiddevicesfromterminal
  - `hidutil list` identifies devices/usage and Apple also describes monitoring/report facilities.
- HID input callbacks: https://developer.apple.com/documentation/iokit/1438367-iohidmanagerregisterinputvalueca
  - Established IOKit manager route; handle multiple HID collections and hotplug.
- CoreHID: https://developer.apple.com/documentation/corehid
  - Newer API to assess for availability/deployment version; do not assume it replaces IOKit for our target without verifying.
- Event taps: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
  - Host-translated event inspection/interception; may need Input Monitoring or Accessibility and may not give robust device identity.
- Synthetic scroll events: https://developer.apple.com/documentation/coregraphics/cgeventcreatescrollwheelevent
  - Requires attention to axis order, sign, units, event origin and self-generated-event loops.
- Active application: https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification
  - App profile routing.

**Do not assume that successfully observing raw HID with IOKit automatically allows suppression of its original events in user space.** Global host event taps often see translated events and reliable device-specific filtering can be difficult. This is the principal feasibility risk for complete, conflict-free remapping.

## Portable development references

- Swift Linux toolchain: https://www.swift.org/install/linux/
- Swift platform support: https://www.swift.org/platform-support/
- Cross-platform `swift test`: https://www.swift.org/documentation/server/guides/testing.html
- Swift Testing: https://github.com/swiftlang/swift-testing
- GitHub-hosted macOS and Linux runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Linux libinput debug-events: https://manpages.debian.org/unstable/libinput-tools/libinput-debug-events.1.en.html

The preferred first step is **cross-platform, pure Swift** for domain rules, fixture playback and tests, then macOS SwiftUI/IOKit adapter later. Reevaluate after inspecting toolchains and upstream code. Do not build an Apple-only app that cannot be tested in the current Linux environment.

## Maintenance and release approach

- Use pinned dependencies, tests for button state machine and JSON config migrations, GitHub Actions on Linux, optionally a macOS build matrix as native code arrives.
- Monitor Apple macOS SDK changes, relevant upstream LinearMouse releases and issue regressions; run physical VMD smoke tests on new macOS versions.
- Keep a changelog, redacted diagnostic export and compatibility matrix by macOS/CPU/VMD variant.
- Once actually distributing: Developer ID signing, notarization and optionally Sparkle automatic updates. Confirm live Apple requirements before release.
- Prefer a user-space helper with narrowly scoped permissions; defer DriverKit until concrete technical evidence justifies extra entitlements/signing burden.

## Research questions for Codex to challenge

- Would a thin Evoluent-specific LinearMouse configuration/plugin give a substantially simpler and more maintainable first release?
- Are input-source identification and per-device suppression feasible without DriverKit on the target macOS versions? Prototype before committing.
- Does VMD generate native horizontal wheel data while lower thumb held? If so avoid duplicating transformation.
- What do we lose with a full standalone app compared to an upstream contribution or fork? Licensing, ease of updating, GUI quality and risks of breakage should matter.
- Can we use GitHub Actions macOS runners to **compile** native code before owning a Mac, while clearly marking hardware tests as pending?
