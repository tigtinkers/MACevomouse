# Local shortcut MVP and hardware gate

## Current scope

The local app saves validated shortcuts for the observed 6780:401 mouse. Live output is restricted to **wheel click**, pending physical validation. Lower thumb is reserved for native horizontal scrolling. All other saved assignments are preparation only. Every launch starts disabled. The assignment preview tab remains a synthetic lab, separate from saved settings.

## Build and launch

```bash
swift test
Scripts/build-app.sh
open .build/MACevomouse.app
```

In a restricted development sandbox, use a writable module cache and pass `--disable-sandbox` to SwiftPM or the build script as needed. The package has no downloaded build dependencies. The generated `.app` is ad hoc signed with identifier `org.tigtinkers.MACevomouse`; it is a local development artifact, not a notarized release. Rebuilds may require renewed macOS permission approval. Do not run two copies while testing.

## First wheel-click experiment

1. Quit the previous inspector. Open the generated app, select the Evoluent interface under **Hardware trials**, then open **Assignments**. This explicitly selects one interface; no registry IDs or serials are saved.
2. Select **Wheel click**, enter `command+a`, and **Save Assignments**. Use a disposable text document with text for a harmless Select All test. Do not start with Dictation.
3. Click **Check / request permissions** if needed. The user controls Accessibility/Input Monitoring approvals in macOS. No permissions are requested at startup. Restart the app if macOS requires it, then reselect the device.
4. Click **Probe selected mouse for 10 seconds**. After the three-second delay, press and release only its wheel click once. Let the probe stop automatically. Expected log: one selected-device host button 4 down and up. If nothing appears or the button differs, copy the log/status and stop here. Missing or mismatched sender IDs never enable output.
5. Only after that labeled trial matches, confirm the checkbox. Click **Enable experimental wheel-click shortcut**. In the disposable document, wheel click once. Expect one Select All action. Confirm that the button's original action did not also occur in an app where the original action is observable. Repeat several times; hold and release once. Return to **Assignments** to use **Disable now**.
6. Test ordinary clicks, dragging, vertical scrolling, lower-thumb horizontal scrolling, and another pointing device. If another mouse has the same host button, test it specifically. A trackpad pointer test alone cannot verify that same-button case.
7. Test disable during a held wheel click, device disconnect, reconnect, sleep/wake, and session changes. Each reset requires a new probe and explicit enablement. Reconnect must not silently reuse an old identity.
8. Record actual results below. If any duplicate action, stuck input or unrelated-device effect occurs, disable immediately and leave live operation off while investigating.

The callback mask observes only other-mouse down/up events. It resolves sender identity first; unrelated events are passed through and never recorded. It never listens to keyboard input. Physical output is limited to a complete tagged keyboard down/up pair. No held modifiers or background keyboard recording are implemented.

## Dictation

After the harmless test passes, confirm the shortcut configured in macOS **System Settings → Keyboard → Dictation**. Enter or record that same supported chord for wheel click, select **Use this assignment for Dictation**, and confirm it. The app does not change Dictation settings or assume a default shortcut. Fn-only and repeated-modifier shortcuts are unsupported; a supported chord must be configured by the user. Verify actual Dictation activation in a text field; injection success cannot be inferred from an event constructor test.

## Profile storage and capture export

Saved settings use `~/Library/Application Support/MACevomouse/shortcuts.json`. Empty assignments retain native behavior. Saves are validated and atomic. A failed load preserves the file and the store's in-memory last valid profile. Existing standalone core configuration strings can be migrated by `ShortcutProfile.decode` only when they describe one explicitly matched 6780:401 profile with primary shortcuts and native scrolling; unsupported features fail instead of being discarded. There is no automatic search/import of arbitrary old files.

**Hardware trials → Export JSON** exports only the current selected-interface raw capture, including trial label, relative microseconds, report/usage/value, movement-filter flag and omitted-value count. No serial, physical path, registry ID or application context is exported. Exported diagnostic documents are not simulator replay fixtures. Stale values before capture start are filtered. Keep host probe logs separate from raw HID evidence.

## Acceptance record

All physical rows below remain **UNKNOWN** for the new adapter until tested by the user:

| Check | Status |
| --- | --- |
| Selected-interface sender identity matches wheel-click trial | UNKNOWN |
| Exactly one shortcut, original action suppressed | UNKNOWN |
| Other mouse / trackpad unaffected | UNKNOWN |
| Disable, disconnect and reconnect recovery | UNKNOWN |
| Vertical and horizontal scrolling preserved with adapter enabled | UNKNOWN |
| Sleep/wake and session recovery | UNKNOWN |
| Permission denial/revocation fallback | UNKNOWN |
| Dictation activates with the configured shortcut | UNKNOWN |

After these pass, expand live mapping one control at a time with its own matched host-event evidence; primary/right-button changes additionally require drag lifecycle support. Per-app profiles, held keys, double clicks, arbitrary actions, launch-at-login, updates and public distribution remain later milestones.
