# Header settlement and consistent project/tag rows

30 October 2026. Branch `task/HEADER-SNAP-AND-ROWS`, based on `3fbf200`.

## Result

- Removed the separate gray material rectangles. The header, period controls and month heading match the screen canvas; native navigation/buttons keep their system glass.
- Tags and projects share a 28 pt icon column, 12 pt icon/text spacing, 16 pt horizontal row insets, body-medium titles and footnote metadata. Tag color markers grow from 12 to 22 pt.
- Upcoming Month now places `NativeModeHeader` above its scrolling surface, matching the other workspaces. The large title scales/fades in its fixed area rather than being carried under the navigation bar. Removed the title's own clipping so its glyphs are not sliced during collapse. The compact toolbar title fades in using the same progress.
- The actual scrolling surface settles from the 0–80 pt transition to fully open or closed after touch/deceleration. The nearest endpoint is chosen at 40 pt. If short content cannot reach 80, it settles open. Disabled/actively tracked/dragging/decelerating scroll views are untouched. Programmatic date/time/agenda navigation is excluded.
- The List/ScrollView bridge observes its own layout and matches the nearest viewport, including safe-area extensions. It never replaces the system scroll delegate or pan recognizer. Its invisible SwiftUI layer explicitly ignores hit testing.
- Replaced the month grid's SwiftUI drag with a direction-gated native recognizer attached to its enclosing scroll view. Vertical pans fail the horizontal recognizer before it begins; horizontal pans still change months. Its layout marker also ignores hit testing. Gesture coordinates are tracked in the window because the system can reset pan translation at release.

## Verification and limits

- Simulator Debug build passed, dedicated Orbit Productivity QA / iPhone 17 / iOS 27.0, synthetic data only.
- Signed physical-device Debug build passed, iPhoneAtl / iOS 27.2.
- Final fixed-header build installed over the existing app on iPhoneAtl and launched successfully; user data was retained. Physical touch acceptance remains for the user.
- A separate native harness extracted the exact settlement handler from this source and exercised ten UIScrollView positions: both sides of the threshold, exact threshold, offsets outside the transition, negative bounce, nonzero top inset, too-short content, and disabled scrolling. All passed; see `native-settlement.txt`. This checks real UIScrollView offsets, not a duplicate arithmetic implementation.
- GUI: light and dark canvas/row appearance; matching project/tag title alignment and larger color marker; horizontal month swipes October → November → October; vertical scroll starting on the month grid; large/compact header endpoints; reverse scrolling; shared list scroll connection. Temporary phase diagnostics confirmed the actual native List and ScrollView connections, then were removed.
- The final white-theme month screenshots use the fixed header; earlier dark month screenshots capture the shared fade/gesture work before the last physical-device clipping correction.
- No FPS measurement, full Dynamic Type matrix, physical touch acceptance or old-runtime pass is claimed. Native settlement harness coverage is distinct from the GUI gesture checks.
- No schema/store changes, test-data cleanup, uninstall, push or TestFlight upload. Existing unrelated README/TASKS/handoff/audit changes were retained and excluded from this commit.
