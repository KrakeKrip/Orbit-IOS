#!/bin/bash
# Build only. Run after the OrbitIOS Simulator build. No device install, store
# access, notification permission changes, or automatic test execution here.
set -euo pipefail
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
products="${1:-/private/tmp/orbit-design-unify/Build/Products/Debug-iphonesimulator}"
probe_dir=$(mktemp -d /private/tmp/orbit-notification-probe.XXXXXX)
probe_app="$probe_dir/Probe.app"
mkdir "$probe_app"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -sdk "$sdk" \
  -target arm64-apple-ios17.0-simulator -parse-as-library -I "$products" \
  reports/CALENDAR-REMINDER-QA/NotificationProbe.swift \
  apple/OrbitIOS/OrbitIOS/IOSReminderNotificationClient.swift \
  apple/OrbitIOS/OrbitIOS/ReminderSound+Notification.swift \
  "$products/OrbitCore.o" -o "$probe_app/Probe"
python3 - "$probe_app" <<'PY'
import plistlib, sys
from pathlib import Path
(Path(sys.argv[1]) / 'Info.plist').write_bytes(plistlib.dumps({
  'CFBundleIdentifier': 'local.orbit.notification-probe',
  'CFBundleName': 'Orbit Probe', 'CFBundleDisplayName': 'Orbit Probe',
  'CFBundleExecutable': 'Probe', 'CFBundlePackageType': 'APPL',
  'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0',
  'MinimumOSVersion': '17.0', 'LSRequiresIPhoneOS': True,
  'UIDeviceFamily': [1], 'UILaunchScreen': {}
}))
PY
codesign --force --sign - "$probe_app"
printf 'Built Simulator-only probe: %s\n' "$probe_app"
