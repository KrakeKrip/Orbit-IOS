# NATIVE-CREATE-COMPACT — self-check

Base b7cf4c5. Shared form groups project/date/time into one section, uses 8pt section gaps, moves deadline/reminder into collapsed Additional, fixes Cancel/Add above scrolling content and keyboard. Single large detent avoids intermediate sheet resizing; keyboard dismisses interactively. Existing optional draft, whole-candidate save and explicit date semantics preserved.

Action menu: remove queued async opening; anchor/presentation state render together. Disable modal transition animations for this action card, including outside-dismiss binding. Fast outside tap can close without waiting for transition. Editors still dispatch after menu disappears.

Creation: latch accepted hold with creationDay until drag ends. LongPress changing its value after fast movement no longer freezes candidate at30/40 minutes; final callback uses latched draft.

Checks:
- Final Simulator + signed device BUILD SUCCEEDED; diff --check clean. Core123 PASS in preceding autoscroll commit; no core changes here.
- CUA own simulator: all base fields, Additional and fixed Cancel/Add visible with software keyboard; blank Add disabled. Cancel closes in one click with keyboard open. Additional opens deadline + reminder, collapses keyboard. Screenshot inspected on live GUI, evidence outside repo: orbit-outputs/NATIVE-CREATE-COMPACT/compact-keyboard.png and additional.png.
- Rapid consecutive coordinate clicks task then empty calendar: menu absent in resulting full AX tree; previous implementation stayed open in same check. No forced wait between clicks.
- CUA drag from empty12:15 lane downward260screen pixels: create draft12:15/190min, preview end15:25. Title Протянуть быстро and fixed Add save exactly this interval; live calendar confirms12:15–15:25; own read-only SQLite confirms date2026-10-18/time12:15/duration190. Original4 fixture tasks retained; total5. Cancel tests create no extra rows.
- Final signed update installed in place on iPhoneAtl: devicectl success databaseSequenceNumber2644. No uninstall or personal-store access. No push/merge.

Limits: fast drag is synthetic CUA, not physical finger speed QA. iPhone haptics, resize/move edge-hold, upper-edge gesture, AXL, VoiceOver and dark-theme GUI not checked in this pass. Swipe dismissal with keyboard is still system-controlled; fixed Cancel is the reliable immediate close path. Creation/scrolling same-day only; untimed external drop autoscroll and cross-date drag remain future scopes.
