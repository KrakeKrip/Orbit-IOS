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

## R1 — user-found scroll regression and spacing

The prior simultaneous DragGesture(minimumDistance:0) captured ordinary scrolling and LongPress onChanged(true) was incorrectly treated as hold acceptance. Source-only latch repair was insufficient; replaced creation recognition with UILongPressGestureRecognizer attached only to the locally resolved timeline UIScrollView. It begins after0.45s stationary hold, allows native pan simultaneously, ignores occupied time bands and gutter, tracks continuous changed events, clears on ended/cancelled/failed, removes recognizer on dismantle. SwiftUI no longer installs a zero-distance drag on the empty grid.

Final Simulator + signed-device build PASS. CUA ordinary drags leave create sheet absent and scroll forward to visible15:00–24:00, reverse to00:00–10:00 (screens visually inspected). Deliberate1000ms hold at scrolled16:40 opens30min draft/end17:10; Cancel closes without submit. This supersedes the earlier quick-drag evidence, which did not verify scroll-versus-hold separation. Continuous physical hold-and-drag after the native recognizer replacement remains unverified.

Menu height now measures actual content instead of reserving estimated preview space; GUI all actions through Delete visible, reduced bottom gap. Create header top padding increased8pt beneath sheet grabber. No core changes;123-test prior result retained rather than rerun unchanged core.
