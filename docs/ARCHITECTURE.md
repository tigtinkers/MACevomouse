# Architecture, roadmap, and maintenance strategy

Updated October 16, 2026. This is a working recommendation, not a mandatory design freeze.

## Main recommendation

**User-space macOS software before a custom device driver**: the stock macOS HID stack should continue to provide core pointer input. A device-specific settings app and carefully scoped input service should handle remapping, navigation, scrolling and profiles if tests establish this is feasible.

**Linux first:** implement a portable rule engine with mock event inputs and deterministic tests. Investigate macOS-specific event interception and source attribution before committing to a complicated system extension architecture.

## Proposed layered design

```text
Actual VMD USB HID               JSON fixture replay (works on Linux)
       |                                    |
macOS HID/CGEvent adapter                 CLI adapter
       |                                    |
       +------------- input model ---------+
                             |
                   device identity/filter
                             |
                  normalization + ordering
                             |
                held-button/chord state machine
                             |
                    profile/rule resolver
                             |
                  action/scroll intent model
                             |
                  +----------+-----------+
                  |                      |
             Linux CLI logs       macOS action adapter
             (no injection)       (future injection/control)
                                         |
                                 macOS foreground apps

Future SwiftUI control panel edits versioned profiles and displays test results.
```

### Main portable modules (working proposal)

- `HIDCore`: `DeviceIdentity`, `InputEvent`, `RawHIDSample`, `HostEvent`, `InputSource`, `ButtonState`, `ScrollAxis`, `ActionIntent` and typed errors; no AppKit/Iokit.
- `RuleEngine`: deterministic state machine; tap/hold/chord, scroll transforms and app/profile rule precedence.
- `ProfileStore`: Codable versioned config with validation/migrations, defaults and JSON import/export.
- `FixtureReplay` / `macevo-cli`: load synthetic captures, replay ordered events, print action intents and diagnostic summaries; explicit `--source synthetic`.
- `MacHIDAdapter` (later): IOKit/CoreHID enumeration, capture/monitoring, attach/detach and event attribution.
- `MacEventAdapter` (later): safe CGEvent tap filtering, host event injection where needed, suppression and self-event loop protection.
- `MacUI` (later): SwiftUI native UI, per-device button diagram, live mapping recorder, app profiles and permissions diagnostics.
- `MacAgent` (later): per-user background service/login item as needed (not a privileged kernel extension by default).

Inspect and adapt these names if a better layout emerges. The core must compile on Linux without importing Apple-only frameworks.

## Key engineering complexities

1. **Device source attribution:** host CGEvents may not retain a reliable HID device identity. Prove single-Evoluent-only intervention before capturing or suppressing globally.
2. **Event suppression:** observing HID reports does not mean macOS will let an ordinary app discard only that source's native events. Explore a thin existing engine, event-tap APIs and a limited fallback. DriverKit should be an evidence-based escalation only.
3. **Chord timeline:** lower thumb may be firmware modifier or independent event; modifier + wheel requires precise down/up ordering, release transitions and no duplicate horizontal events.
4. **State recovery:** dropped release, unplug mid-hold, sleep/wake, active app/profile change and app crash must not leave held keys/buttons latched.
5. **Inert diagnostics:** no interference with a working mouse until basic mapping verified.
6. **Permissions:** ask for accessibility/input monitoring only when needed; no admin rights by default; explain exactly why each permission is requested.
7. **Synthetic output:** distinguish action intents from events actually posted to macOS; macOS correctness needs hardware testing.
8. **Compatibility:** multiple VMD USB subtypes and macOS versions; avoid hard-coded product and vendor IDs until captured and confirmed.
9. **Licenses:** prefer copying no code at first. MIT LinearMouse code requires license notice; MMF 3 has different limitations.

## Build matrix

| Work | Linux dev host now | GitHub Actions macOS runner | Physical Mac later |
| --- | --- | --- | --- |
| Core SwiftPM compile/test | YES | YES | YES |
| JSON replay / profiles / rules | YES | YES | YES |
| Native SwiftUI app build | NO | MAYBE (compile, project configured) | YES |
| IOKit/CoreHID compile | NO | MAYBE | YES |
| Detect actual physical VMD under macOS | NO | NO | YES |
| Confirm six button mappings and scrolling | Linux-only possible with device | NO | YES |
| TCC permissions / real input remap UX | NO | NO | YES |
| Sign, notarize, distribute | NO | Potentially with secrets, not milestone 1 | YES later |

Pin stable runners/toolchains once CI exists; a macOS-hosted CI compilation is not proof of physical support.

## Milestones

**M0 — research/docs (now):** product brief, sources, test plan, architecture, agent instructions.

**M1 — Linux-first software scaffold:** SwiftPM core, safe fixture-driven CLI, typed JSON schema/versioning, synthetic test cases for six abstract controls and lower-thumb+wheel, deterministic `swift test`, GitHub Actions Linux CI, documentation and decisions.

**M1b — optional physical Linux enumeration:** passive `lsusb` / `evtest` / `hid-recorder` if VMD actually connected; update findings. This is not required for M1 completion.

**M2 — first real Mac session:** `hidutil list`, native passive SwiftUI/HID Inspector (IOKit), VID/PID and all collections, trial mapping including raw/translated, redacted capture. No remapping yet.

**M3 — controlled user-space functionality:** one selectable Evoluent only; safe enable toggle; basic button remap; lower-thumb+wheel horizontal only after raw behavior established; original event suppression and no double actions; fallback/pass-through.

**M4 — polished app:** button visualizer, click-to-map, shortcuts, app profiles, secondary layers, smoothing, profile backups/import/export and straightforward permissions.

**M5 — reliability/distribution:** Mac hardware QA matrix, sleep/wake, reconnection, updates, recovery, signing/notarization, Sparkle or other updates, documentation.

## Build-vs-fork decision gate

After M2, compare:
- **Configure LinearMouse**: if it can expose all VMD controls and chord, little proprietary code is necessary.
- **Fork/extend LinearMouse**: sensible if its event handling works but UI or VMD-specific behavior is missing; preserve MIT license and upstream merge strategy.
- **Independent app**: justified if we need a dedicated UX, maintainability/feature isolation or API pattern significantly different from upstream.
- **Advanced HID virtual device / DriverKit**: last resort if normal user-space capture+suppression cannot achieve per-device remapping and the benefit outweighs signing/permissions complexity.

Document the decision and the proof behind it instead of selecting solely by intuition.

## Update and support policy

- Monitor upstream LinearMouse and Mac Mouse Fix issues/release notes for macOS regressions without automatic imports.
- GitHub Actions Linux tests on every PR; add macOS build-only jobs when native code exists.
- Add fixture-based regression tests from redacted physical data.
- Maintain `docs/HID_FINDINGS.md`, `docs/DECISIONS.md`, versioned configuration migrations and a `docs/COMPATIBILITY.md` matrix.
- Test each significant macOS upgrade/beta with actual mouse: launch agent, permissions, buttons, scroll axes, per-app rules, sleep/wake and other mice.
- Distribute only after macOS Developer ID signing/notarization and rollback/uninstall instructions have been implemented and manually verified.
- Only add a Sparkle updater (https://sparkle-project.org/) after a supported release packaging plan exists.

## Risk register

| Risk | Likelihood / severity (pre-data) | Mitigation |
| --- | --- | --- |
| Lower thumb not independently readable | Unknown / High | Determine firmware wheel transformation; alternate chords/UI |
| Six physical controls cannot all be remapped | Unknown / High | Capture raw+host layers; reduce promised feature set |
| CGEvent lacks reliable per-device source | Moderate concern / High | Prototype selectively; upstream comparison |
| Native Mac compile works but runtime permissions fail | Moderate / High | Physical Mac smoke test and clear permission diagnostics |
| Linux tooling unavailable | Unknown / Low | Official Swift container or document unexecuted test status |
| Duplicate scroll injection / event loops | Moderate / High | Intent model, filtering, loop provenance, pass-through safety |
| Upstream code license misuse | Avoidable / Medium | Source review and attribution, no unlicensed copying |

All risks are hypotheses until supported by live observations.
