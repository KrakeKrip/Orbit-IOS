# Calendar header boundary fix — 2026-10-30

Reported: the calendar freezes when scrolled to the end of the day.

The calendar header previously accumulated scroll geometry deltas, including layout corrections and boundary bounce. This creates a feedback risk between geometry and header state. It now derives progress from the native finger translation relative to the start of the gesture, clamps it to 0…80, and ignores deceleration geometry. The header settles independently without repositioning the calendar. Other list observers are unchanged.

## Verification

- Debug Simulator build passed; installed on isolated Orbit Productivity QA with synthetic data.
- Reached 24:00 in Today calendar, attempted another upward swipe at the boundary, then successfully opened the toolbar menu. See bottom-menu-responsive.png.
- Original freeze was user-reported, not independently reproduced before the change. This is a bounded check, not complete gesture regression coverage.
- Release device build passed, log: /private/tmp/orbit-bottom-pan-build.log.
- No data model changes, no TestFlight upload. Existing unrelated working tree changes preserved.
- Installed Release 0.2.0 (4) on the paired iPhone over the existing app; device interaction acceptance remains pending. Install log: /private/tmp/orbit-bottom-pan-install.log.
