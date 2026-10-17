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
| VID/PID | NOT OBSERVED | NOT OBSERVED | PENDING | n/a |
| All six physical controls mapped by location | NOT OBSERVED | NOT OBSERVED | PENDING | PENDING |
| Lower-thumb standalone report | NOT OBSERVED | NOT OBSERVED | PENDING | PENDING |
| Lower-thumb + wheel behavior | NOT OBSERVED | NOT OBSERVED | PENDING | PENDING |
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
