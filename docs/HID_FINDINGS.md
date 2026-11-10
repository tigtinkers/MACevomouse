# HID findings and evidence log

Updated October 16, 2026. This log contains observations, not capability claims.

## Linux M1 inventory — October 16, 2026

| Item | Result | Status |
| --- | --- | --- |
| Host | Linux Mint 22.3, kernel `7.0.0-31-generic` | CONFIRMED |
| `swift` | Not installed / not found on `PATH` | CONFIRMED |
| Docker | Not found on `PATH` | CONFIRMED |
| `lsusb` | Installed; inventory did not identify an Evoluent/VerticalMouse device | CONFIRMED |
| `evtest`, `libinput`, `hid-recorder` | Not found on `PATH` | CONFIRMED |
| `/proc/bus/input/devices` Evoluent match | No match | CONFIRMED |
| `/dev/input/by-id` / `/dev/hidraw*` VMD match | No matching VMD device identified | CONFIRMED |

No `evtest`, raw-HID capture, device grabbing, control transfer, firmware action, or kernel driver change was performed. Absence from this inventory is not proof that the mouse cannot work on Linux; it only means there is no verified VMD available for this M1 session.

## Observation matrix

| Observation | Linux evdev | Linux raw HID | macOS raw HID | macOS CGEvent |
| --- | --- | --- | --- | --- |
| VID/PID | NOT OBSERVED | NOT OBSERVED | OBSERVED: 0x1a7c:0x0191 | n/a |
| All six physical controls mapped by location | NOT OBSERVED | NOT OBSERVED | OBSERVED in user-labeled trials | PENDING |
| Lower-thumb standalone report | NOT OBSERVED | NOT OBSERVED | OBSERVED: button usage 6 | PENDING |
| Lower-thumb + wheel behavior | NOT OBSERVED | NOT OBSERVED | OBSERVED: AC Pan | Visible horizontal scroll confirmed by user; fields pending |
| Pointer-speed input report | NOT OBSERVED | NOT OBSERVED | PENDING | PENDING |

The checked-in fixture and CLI output are **SYNTHETIC**, not substitute rows in this table.

## Evidence handling requirements for the next capture

1. Record OS version, tool version, VMD transport/variant if visible, and a redacted logical device reference; do not retain serials, physical paths, usernames, or unrelated application content.
2. Use a selected device/interface only. Keep raw HID and host translated output separate, and include report ID where available.
3. Run one labelled action at a time using T01–T14 in `HARDWARE_DIAGNOSTICS.md`; particularly repeat T06–T09 before designing a lower-thumb mapping.
4. Mark each result `OBSERVED`, `NOT OBSERVED`, or `INCONCLUSIVE`, include the evidence filename/checksum, and state exactly which layer/tool saw it.
5. Do not enable suppression, injection, virtual HID, device seize, DriverKit, or firmware changes during passive diagnosis.

## Mac/Xcode integration checklist

- [ ] Install Xcode and record `xcodebuild -version`; build the Swift package.
- [ ] Compare `hidutil list` and redacted `system_profiler SPUSBDataType` before and after connecting the VMD.
- [ ] Add a passive `IOHIDManager` selected-device adapter with attach/detach logging; do not infer source identity from a generic CGEvent alone.
- [ ] Run labelled raw-HID and translated-event trials for all controls, wheel axes, lower-thumb chord, pointer-speed button, reconnect, and another mouse.
- [ ] Confirm accessibility/input-monitoring need and present plain-language permission UI before an event tap.
- [ ] Prototype a one-device, pass-through-first interception path; prove no duplicate scroll and no impact on trackpad/other mouse before remapping.
- [ ] Add a SwiftUI control panel only after it can display observed controls and a reliable enable/disable/recovery state.

## Mac preparation — November 5, 2026

- **CONFIRMED:** Development host reports macOS 27.2, Xcode 27.2 and Apple Swift 6.4.2. The Swift package and experimental macOS inspector compile, and synthetic tests run on this host.
- **UNKNOWN:** The VMD was not connected for this work. No device identity, HID capture, translated event, permission flow or button mapping was verified.
- **UNKNOWN:** Inspector runtime behavior on the VMD and correlation between raw and translated events. The experimental inspector only shows raw values from a manually selected interface and is not an evidence export tool.

## First-session preparation

- **CONFIRMED (software only):** The inspector offers a labeled T01–T14 selector and short, in-memory raw-value capture for an explicitly selected interface. It excludes keyboard and consumer pages; an empty capture does not prove a control is invisible. HID timestamps are raw platform ticks.
- **CONFIRMED (software only):** The assignment tab is an unsaved synthetic preview, not a control-identification or remapping tool. It exercises primary and secondary assignments, shortcut text, Mac action names, and simulated wheel intents.
- **UNKNOWN:** Actual device interfaces, TCC behavior, capture completeness, translated events, source attribution, and safe suppression. Compare the selected interface against before/after `hidutil list`, repeat trials on relevant interfaces, and keep findings redacted.

## Connected-device inventory — November 5, 2026

- **CONFIRMED:** `hidutil list` reported a USB HID collection with product string `Evoluent VerticalMouse 4`, vendor ID `0x1a7c`, product ID `0x0191`, usage page `0x01` and usage `0x02` (mouse). The user reports connecting the mouse through a hub. This is an initial snapshot; no disconnected baseline was taken.
- **UNKNOWN:** Whether the reported product string identifies the physical model accurately, whether other collections belong to this device, and which events correspond to physical controls. No button inputs were captured in this inventory. `system_profiler SPUSBDataType` produced no matching product entry in this session.

## T01 initial trial — November 9, 2026

- **OBSERVED:** User-supplied T01 output contains report 0, button usage page 9, usage 1 values 1 and 0. This is a candidate top finger press/release mapping; a clean isolated repeat is needed to confirm the physical association. The initial capture also contained substantial pointer movement and reached the 250-line limit.
- **CONFIRMED (source/build):** Inspector now waits three seconds, excludes X/Y movement by default, suppresses repeated timestamps for each element, reports truncation and offers Copy Results. Hardware behavior of this revision remains unverified.

## Thumb-wheel investigation — November 9, 2026

- **OBSERVED (user-reported):** Two T08 trials showed lower-thumb usage 6 down/up but no new wheel values on the previously captured pages; no horizontal scrolling was visible.
- **UNKNOWN:** Whether another element or interface reports wheel movement during the chord. Inspector now provides selected-interface element metadata and includes consumer AC Pan (page 12, usage 568) in bounded capture; this revision has not yet been tested with hardware. Keyboard and other consumer input remain excluded.

## Physical trials T01–T08 — November 9, 2026

- **OBSERVED (user-labeled raw HID trials, selected interface):** Product `Evoluent VerticalMouse 4`, VID `0x1a7c`, PID `0x0191`, report 0. Button page 9 usages: top finger 1, middle finger 3, bottom finger 2, wheel click 5, upper thumb 4, lower thumb 6. Each trial included press and release; T01 also contained additional presses associated with interaction during capture.
- **OBSERVED:** T07 wheel alone produced positive and negative values on generic desktop page 1 usage 56. T08 held lower thumb (page 9 usage 6) while the wheel produced positive and negative values on consumer page 12 usage 568 (AC Pan), followed by thumb release. The selected interface's element inventory includes both wheel and AC Pan.
- **OBSERVED (user-reported):** No horizontal scrolling was visible during the earlier trial; application and scrollable content were not specified. Raw HID visibility does not establish macOS translated events or application behavior.
- **UNKNOWN:** Actual hardware model versus its reported product name, whether macOS translates AC Pan, safe event attribution and suppression, and behavior across reconnection or other interfaces. Raw ticks use platform timebase; do not assume microseconds. The T08 output contained older element timestamps at its start; treat those as stale rather than trial events.

## T09 and scroll test — November 9, 2026

- **OBSERVED (user-labeled raw HID trial):** AC Pan values occurred while lower thumb was held; after the thumb release, wheel values resumed on page 1 usage 56. Older timestamps at the start were stale element values.
- **CONFIRMED (source/build):** The inspector has a normal horizontal SwiftUI scroll surface for a manual application-behavior test; it records no host events. This does not establish whether macOS emitted a scroll event.
- **UNKNOWN:** Device-specific host-event attribution. A global scroll event tap could collect events from other pointing devices and has not been enabled under the project's selected-device-only collection constraint.
- **OBSERVED (user-reported):** In the inspector's horizontal scroll test, lower-thumb plus wheel moved the horizontal strip. Wheel without thumb did not move that strip. The test strip only scrolls horizontally; this does not establish whether ordinary vertical scrolling works elsewhere or establish exact translated-event fields.

## Saved shortcut / attribution adapter preparation — November 9, 2026

- **OBSERVED (user-reported):** Normal vertical scrolling in a vertically scrollable page and lower-thumb horizontal scrolling in the app test strip both work. Preserve these native paths.
- **CONFIRMED (automated):** The app and local ad hoc signed bundle build. Sender-attribution symbols resolve on the host. Tests cover typed shortcuts, storage failure behavior, supported legacy migration, strict synthetic routing and tagged keyboard pair construction without posting.
- **UNKNOWN:** The new attribution probe and live adapter have not been activated on the physical mouse. No permission grant, host button match, original-event suppression, Dictation, reconnect or other-device isolation result is claimed. Follow `MVP_TESTING.md` before expanding past wheel click.
