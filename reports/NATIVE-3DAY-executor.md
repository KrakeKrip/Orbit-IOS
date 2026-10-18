# NATIVE-3DAY — Codex self-check

Base119b957; task/NATIVE-3DAY. Fourth Upcoming-only mode persisted separately; existing mode setters make choices mutually exclusive. One scroll surface/ruler for three civil columns, bounded1900–2199 window (last day showsDec29–31), per-column untimed region, reuse shared task popover/editor/create/rename/delete/selection. Marked date picker + arrows±3; column heading selects date for shared FAB. Initial flexible header spacer caused excess height; fixed64pt header before final GUI.

TaskTimelineWindow supplies UTC civil arithmetic and stable overlap lane placement. Store setPlannedSchedule validates entire date/time/duration before mutations, no-op guard, one save/rollback; other fields untouched. Timed gestures freeze source fields, check schedule conflict on release and use existing5-minute move/10-minute duration/min5 rules. Both handles retain identity while active. Empty creation reuses the accepted native recognizer; ghost stays until form dismisses. Shared30Hz edge scrolling adds actual offset delta to frozen finger translation. No schema changes.

## Checks
- Full129 core tests /17 suites PASS. Four new tests: civil window boundaries includingInt.min, overlapping/touching lanes, disk reopen+metadata preservation, invalid candidate matrix/no mutation/retry/unknown UUID.
- Final Simulator and signed device BUILD SUCCEEDED; diff --check PASS. Initial compile needed an escaping ViewBuilder closure; corrected before GUI.
- CUA own simulator: mode entry and persisted mode after terminate/relaunch; three columns18/19/20 with shared08:00 ruler; untimed tasks aligned per day; nav21/22/23 thenback18/19/20.
- Real move: hold Плавный переход on18Oct10:05 then drag to19Oct11:00; lower handle→11:00–12:00; upper handle→11:20–12:00. Relaunch retains target day/interval. Own read-only SQLite confirms19Oct/11:20/40.
- Empty third column hold→create20Oct10:10/30; Cyrillic title Третий день, Add→correct column/date10:10–10:40; SQLite confirms. Bottom-edge hold1800ms in second column opens19Oct15:30/150min (automatic scroll while stationary); Cancel no added row, total7 synthetic tasks.
- Screenshot visually inspected in live CUA: compact header, all3columns and time range. Evidence outside repository: orbit-outputs/NATIVE-3DAY/three-days.png, rows.json. No personal store read.

- Signed build installed in place on iPhoneAtl successfully (device database sequence2684); no uninstall. Physical interaction with this build remains unverified.

## Limits
Physical finger/haptics, AXL/VoiceOver/dark theme, overlapped-task GUI and overnight-segment GUI, store disk-failure injection remain unverified. Overlap/window/store logic covered by core tests; projector overnight coverage is existing. Drag stays inside the currently visible three-day window, no horizontal edge paging. External untimed drag/return zones are not added to this mode (use menu/time editor or one-day view). Navigation uses arrows/date picker; horizontal window swipe not added. Selection and shared actions use existing hosts; exhaustive bulk GUI not repeated. No push/merge in this task.

## Follow-up: untimed expansion
User requested the existing day-calendar pattern in three-day mode. Collapsed columns now show at most three fixed-height rows with remaining count, without a nested scroll. Shared gutter button expands all columns up to seven rows; only columns with more than seven tasks scroll in expanded state. Collapse and page navigation restore compact presentation. Simulator BUILD SUCCEEDED; diff --check PASS. This follow-up has not yet had GUI/physical-device verification or installation.
