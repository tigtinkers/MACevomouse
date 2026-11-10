#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build "$@" --product macevo-inspector
macevo_bin_dir="$(swift build "$@" --show-bin-path)"
macevo_app="$PWD/.build/MACevomouse.app"
mkdir -p "$macevo_app/Contents/MacOS"
cp "$macevo_bin_dir/macevo-inspector" "$macevo_app/Contents/MacOS/MACevomouse"
cat > "$macevo_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.tigtinkers.MACevomouse</string>
<key>CFBundleName</key><string>MACevomouse</string>
<key>CFBundleExecutable</key><string>MACevomouse</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Observe an explicitly selected mouse for diagnostics and an experimental wheel-click shortcut.</string>
</dict></plist>
PLIST
mkdir -p "$macevo_app/Contents/Resources/ThirdParty"
cp ThirdParty/README.md ThirdParty/LinearMouse.LICENSE "$macevo_app/Contents/Resources/ThirdParty/"
codesign --force --sign - "$macevo_app"
codesign --verify --strict "$macevo_app"
printf 'Built %s\n' "$macevo_app"
