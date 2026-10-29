# Month navigation, project sections and frosted headers

30 October 2026. Branch `task/MONTH-NAVIGATION`, based on `a2cf85c`.

## Delivered

- Upcoming Month removes the redundant “Selected” row. The selected day remains above its tasks.
- Month/year selection opens a separate compact popover with Cancel/Show. Browsing months does not silently change the day used to create a task.
- Horizontal grid swipes move one month; a direction threshold keeps vertical scrolling independent. Arrows and the existing 1900–2199 bounds remain.
- A 44 pt action collapses/expands the grid, keeping its month controls and task list available.
- The month view has one vertical scroll surface including its large header. The header no longer changes the scroll viewport height during deceleration; the compact toolbar title follows the actual scroll offset. Short/empty days also allow an upward scroll.
- Projects and Tags have independent disclosure buttons and separate 44 pt add buttons. Their expanded states are saved on this device. One divider separates the sections; the last tag/empty state has no trailing rule. The floating + still creates a task.
- Broad app headers/period controls use a regular system material with a light theme tint, without beveled panels. Native buttons retain Liquid Glass. Reduce Transparency uses an opaque canvas fallback; disclosure animations respect Reduce Motion. Native navigation bars retain their system rendering.

## Verification

- Debug Simulator build: passed, Orbit Productivity QA (iPhone 17, iOS 27.0).
- Debug signed physical-device build: passed, iPhoneAtl, iOS 27.2.
- GUI with synthetic data: month/year popover; October → November using the wheel and Show; horizontal swipe November → October; full task-list upward scroll showing the compact header; reverse scroll restoring the large title; grid collapse and expansion; empty-day upward scroll; independent Projects/Tags collapse and expansion; persisted collapsed states after app update/relaunch; divider and no rule below the last tag.
- Ivory and dark themes inspected. `month-dark.png` is the final matte material. Earlier ivory screenshots show the navigation/disclosure behavior before the final material adjustment.
- Device install: succeeded over the existing app, bundle `local.orbit.ios`. No uninstall, store reset, schema or persistence-model changes.
- `git diff --check`: passed.

GUI checks establish the interactions in Simulator; no FPS measurement, physical touch acceptance, full Dynamic Type/theme matrix, Reduce Transparency runtime pass or older-runtime pass is claimed. Core/store code was untouched, so no new core tests were added. Existing unrelated README/TASKS/handoff/audit changes were preserved and excluded from this commit. No push or TestFlight upload.
