# Short screen scroll — 2026-10-30

## Request
Empty lists and short Projects pages must spring back at their boundaries instead of scrolling through artificial blank space.

## Changes
- Removed the invisible dynamic Projects footer that deliberately created an 82-point minimum scroll range for header collapse.
- Empty states now account for the existing 88-point bottom content margin within their minimum viewport height rather than adding it beyond the viewport.
- Empty states hide the scroll indicator. Native elastic bounce remains enabled; populated lists retain natural overflow scrolling.

## Verification
- Debug iOS Simulator build passed with Xcode, scheme OrbitIOS.
- Installed on the isolated Orbit Productivity QA simulator (036AA8E5-189C-4AAC-8ED5-9AA954EBDBA6).
- Short Projects page: upward drag returned to the same resting position, with expanded header and no visible right-hand indicator after release.
- git diff --check passed.

## Limits
Empty-state geometry was checked in source and compiled, not separately exercised in GUI. No full regression suite or physical iPhone check was performed in this change. No TestFlight upload or push. Existing unrelated documentation edits were preserved.
