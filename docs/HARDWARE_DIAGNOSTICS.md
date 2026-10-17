# Hardware diagnostics — Linux now, macOS later

Updated: October 16, 2026. All example output is hypothetical unless explicitly marked otherwise.

## What we must learn

1. USB physical transport: wired cable vs USB wireless receiver; size/part number if available.
2. Actual vendor ID (VID), product ID (PID), product/manufacturer strings, and **all** related HID collections/interfaces.
3. HID report descriptor(s), usage pages/usages, report IDs, value encodings, timing and signed wheel axes.
4. Mapping from **physical** controls to host event(s), obtained via labeled one-at-a-time tests, not guessed from HID usage numbers.
5. Whether lower thumb produces independent down/up events, keyboard or consumer events, changes the wheel's report itself to horizontal, or is invisible.
6. Whether the hardware pointer-speed button sends input events or affects only on-device sensor speed.
7. macOS-specific HID and translated event behavior, which is **not proven by Linux traces**.
8. Behavior across disconnect/reconnect, sleep/wake, short presses, drags and repeated inputs.

## Session setup and safety

- Current machine: Linux; mouse presence not yet verified. If absent, **do not fabricate a HID capture**: develop the event models with synthetic fixtures and mark hardware tests pending.
- Only capture the selected Evoluent device. A composite HID interface may emit keyboard-like events: never record ordinary typing or other-device keyboard reports.
- Test using a second mouse/trackpad if possible. Do not use exclusive grabs, firmware writes, vendor control transfers, HID feature SET_REPORT, or kernel driver unbinding in initial diagnostics.
- Collect short event windows with explicit manual actions. Export redacted data only; strip serials, unique paths, user accounts, and application context.
- Distinguish actual hardware evidence from synthetic replay by clear `source: "physical-linux"`, `source: "physical-macos"`, or `source: "synthetic"` fields.

## Step A — Linux inventory (safe, read-only commands)

```bash
uname -a
cat /etc/os-release
command -v lsusb || true
command -v evtest || true
command -v libinput || true
command -v hid-recorder || true
lsusb
lsusb -t
cat /proc/bus/input/devices
ls -l /dev/input/by-id/ /dev/hidraw* 2>/dev/null || true
```

Inspect for Evoluent, VerticalMouse, device path or likely mouse input nodes. To get per-node metadata (substitute actual paths identified above):

```bash
udevadm info --query=property --name=/dev/input/eventX
udevadm info --query=property --name=/dev/hidrawX
```

`ID_VENDOR_ID` / `ID_MODEL_ID` can help tie a particular `eventX` and `hidrawX` to the VMD. Avoid assuming one device means one interface: inspect all matching nodes. Some fields may be missing. Do not commit unsanitized `udevadm` output.

## Step B — Linux host event layer

If the VMD is connected and permission is available, prefer `evtest` for read-only events from the **selected** `/dev/input/eventX`:

```bash
# Show input device list; stop, then select the VMD node.
sudo evtest

# For one confirmed VMD mouse event node:
sudo evtest /dev/input/eventX
```

Alternatively, if supported by the installed version:

```bash
sudo libinput debug-events --device /dev/input/eventX
```

**Never pass `--grab`** to libinput or attempt exclusive mouse seizure in the initial phase. Depending on the system, root may be required to read event nodes. Do not run automated blanket capture of all `/dev/input/event*` devices.

Record a brief labeled sequence for each control, starting and stopping event capture between actions. Note button down/up and wheel axis names (`REL_WHEEL`, `REL_HWHEEL`, higher-resolution variants, etc.) if present. evdev codes are *host decoded*, not the entire USB protocol.

## Step C — Raw HID layer, if necessary and safely accessible

Inspect `hid-tools` (`hid-recorder`, `hid-decode`) from https://gitlab.freedesktop.org/libevdev/hid-tools .

- Extract descriptors using an appropriate read-only method for the matched HID instance.
- Use `hid-recorder` only on a verified VMD hidraw device for short, labeled input capture. Verify supported CLI syntax using `--help` before scripting.
- Do not use output/feature report writes or `hid-replay` against a real input device during the diagnostic milestone.
- Report descriptor and report ID patterns help determine whether multiple physical buttons are in a bitfield or whether the wheel becomes an independent horizontal axis under thumb hold.
- Compare raw HID vs evdev. If a raw event never makes it to evdev, note the distinction. Avoid inferring Mac outcome.

## Step D — Guided physical-action matrix

Separate test trials; wait for release and idle between steps:

| Trial | Action | Investigate |
| --- | --- | --- |
| T01 | Top finger (#1) press, hold, release | Input usage and stability |
| T02 | Middle finger (#2) press, hold, release | Distinguish from wheel click |
| T03 | Bottom finger (#3) press, release | Source event |
| T04 | Scroll wheel click (#4), release | Forward vs other mapped host action |
| T05 | Upper thumb (#5), release | Back vs other mapped action |
| T06 | Lower thumb (#6), hold 1s, release | Discrete event? |
| T07 | Wheel forward and backward alone | Vertical deltas / report units |
| T08 | Lower thumb held + wheel both directions | Horizontal deltas? Modifier event? |
| T09 | Release lower thumb mid-wheel use | State transition and release handling |
| T10 | Pointer speed control once per setting | Firmware-only or host event; pointer movement change |
| T11 | Normal left-button click-and-drag | Never alter default dragging |
| T12 | Quick repeated clicking | Mechanical bouncing / duplicate event analysis |
| T13 | Disconnect/reconnect then repeat T01/T08 | Interface identity and reattach |
| T14 | Other mouse/trackpad event if accessible | Confirm filter excludes other devices |

**Special attention T06 + T08:** manufacturer calls lower thumb "horizontal scroll with wheel" on Windows. This may be implemented by firmware rather than exposed as an independently detectable modifier. It may also vary by OS. Do not double-rotate if the raw data is already horizontal.

## Evidence schema (proposed, not observed)

A sanitized capture should have session metadata (OS, VMD variant if known, host tool, transport, *redacted* device reference), action labels and events. Example **synthetic** record:

```json
{
  "source": "synthetic",
  "trial": "T06",
  "action": "lower-thumb-down",
  "timestampMicros": 1250000,
  "device": "evoluent-selected-device",
  "interface": "candidate-collection-1",
  "layer": "raw-hid",
  "reportId": 1,
  "usagePage": 9,
  "usage": 6,
  "value": 1
}
```

**The page/usage/report values here are fake examples, not a discovered VMD mapping.**

Use a flexible fixture schema (versioned) that can represent both HID usages and evdev / Quartz interpreted events without conflating them. Attach physical position labels manually after trials.

## Mac inventory once Mac is available

```bash
sw_vers
xcodebuild -version
hidutil list
system_profiler SPUSBDataType
```

Optional before/after plug comparison (a second pointer is useful):

```bash
hidutil list > ~/Desktop/hid-before.txt
# Connect VMD
hidutil list > ~/Desktop/hid-after.txt
diff -u ~/Desktop/hid-before.txt ~/Desktop/hid-after.txt
```

Do not commit unsanitized host output. Also assess `hidutil` event/report monitoring using `hidutil help` on the installed macOS version; exact commands can differ.

Then build a minimal native macOS **passive** inspector:
- Discover/select the Evoluent VID/PID from real runtime information, match all HID collections and listen to attach/detach.
- Use IOKit `IOHIDManager` input-value callbacks (or evaluated CoreHID equivalent).
- Record raw input and host-translated CGEvents **separately**; map physical labels with guided trials.
- Avoid event interception/suppression and exclusive seizure until diagnosis is complete.
- Check appropriate TCC permissions; no root/DriverKit for basic passive study unless documentation genuinely warrants it.
- Compare lower-thumb+wheel with and without app, across direct USB/hub if necessary.
- Report `OBSERVED` / `NOT OBSERVED` / `INCONCLUSIVE`; do not turn a missing event into definitive proof without considering the layer observed.

## Findings table to fill

| Observation | Linux evdev | Linux raw HID | macOS raw HID | macOS CGEvent |
| --- | --- | --- | --- | --- |
| VID/PID | pending | pending | pending | n/a |
| All six buttons mapped by position | pending | pending | pending | pending |
| Lower-thumb standalone report | pending | pending | pending | pending |
| Lower-thumb + wheel horizontal behavior | pending | pending | pending | pending |
| Pointer-speed control observable | pending | pending | pending | pending |

At each phase, update `docs/HID_FINDINGS.md` with evidence filenames, confidence, OS/build, variant, command/tool used, redaction checks and remaining unknowns.

## Ready-to-build criterion

A lower-thumb *software* mapping or horizontal-scroll transform is ready for device-specific implementation only after there is meaningful evidence about its actual host behavior and event suppression/duplication risks on macOS. Linux captures alone should never be labeled macOS verification.
