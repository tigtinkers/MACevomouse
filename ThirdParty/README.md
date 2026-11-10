# Upstream review and attribution

The macOS sender-attribution approach was informed by inspection of LinearMouse at commit
`93d38f1981427fde98ceca105c794dae32c58b7e` on November 9, 2026:

- [DeviceManager.swift](https://github.com/linearmouse/linearmouse/blob/93d38f1981427fde98ceca105c794dae32c58b7e/LinearMouse/Device/DeviceManager.swift)
- [EventDeviceSnapshot.swift](https://github.com/linearmouse/linearmouse/blob/93d38f1981427fde98ceca105c794dae32c58b7e/LinearMouse/Device/EventDeviceSnapshot.swift)
- [LinearMouse-Bridging-Header.h](https://github.com/linearmouse/linearmouse/blob/93d38f1981427fde98ceca105c794dae32c58b7e/LinearMouse/LinearMouse-Bridging-Header.h)
- [EventTap.swift](https://github.com/linearmouse/linearmouse/blob/93d38f1981427fde98ceca105c794dae32c58b7e/LinearMouse/EventTap/EventTap.swift)

The original MIT license is included in `LinearMouse.LICENSE`. MACevomouse does not bundle the upstream application or require it to run. Its adapter is a small independent implementation of the same private macOS entry points, with runtime symbol lookup and strict matching. Unlike the reviewed upstream fallback, unidentified events never borrow the last active device.

Undocumented APIs may disappear or change behavior. Symbol presence is not hardware compatibility. No Mac Mouse Fix code was incorporated.
