# Calendar and reminder hardening

22 October 2026. Branch `task/CALENDAR-REMINDER-QA`, based on `261ecc4` (design audit implementation, already installed and launched on the physical iPhone before this stage).

## Changes

- Day and three-day move, resize and creation handlers apply the **release event's position** before the final commit/presentation. Previously they used only the most recent changed event, so a fast final movement could be omitted. A cancelled gesture still never calls the commit path.
- Native long-press recognizers cancel on `UIApplication.willResignActiveNotification`. Both calendar views discard temporary state on inactive as well as background, including Control Center and system prompts. Beginning an edit/creation while inactive is rejected.
- Notification adapter and sound mapping moved into independent production files so the actual code can be compiled into an isolated system probe. Extracted bodies are identical to `261ecc4`; scheduling behavior and core production code unchanged.
- Added two reminder regressions: refill the 64-request budget after a delivery while preserving foreign requests/delivered history; delivery during asynchronous queue verification must not produce a false scheduling error.

No task schema, UUID, migration, notification preference, or personal store changes.

## Validation

**PASS:** iOS Simulator build, `OrbitIOS` scheme, deployment target 17, Xcode 27; 126 Swift tests in 16 suites. `git diff --check` and probe script syntax/build passed.

Commands:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project apple/OrbitIOS/OrbitIOS.xcodeproj -scheme OrbitIOS \
  -sdk iphonesimulator -derivedDataPath /private/tmp/orbit-design-unify \
  CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --package-path apple/Orbit --scratch-path /private/tmp/orbit-design-core-tests
bash reports/CALENDAR-REMINDER-QA/build-probe.sh
```

The script builds only, into a fresh temporary directory; installation and authorization are deliberately separate. Probe source lives outside the app target and is not shipped.

### Calendar GUI

Own iPhone 17 Simulator `Orbit-Design-Unify`, iOS 27, UUID `B99DFA70-E656-4B53-829F-47641F036CEC`, synthetic store only. CUA actions:

- Swipe starting on an overlapping day card scrolls the timeline, with no creation or task interval change.
- Stationary 650 ms hold selects a task and displays handles; normal release does not open its action popover.
- Day resize end: `Встреча с командой`, 11:00–12:00 → 11:00–12:20; start: → 11:10–12:20. Final values observed in UI and in the read-only synthetic SQLite query.
- Selected day task → open Control Center → return: handles/selection are cleared; original interval remains. This tests inactive/resume after release, **not interruption while the same finger is still moving**.
- Three-day swipe starting on a card scrolls to the later hours without creating a draft or modifying the task.
- Three-day creation hold in a scrolled viewport opens a draft on the tapped column (23 October) at 22:25 for 30 minutes, rather than from midnight. Cancel closes it without a write.
- [Read-only store check](store-check.txt): 17 tasks retained; only the intentional meeting resize changed since the previous report. Five-minute tasks, long overlapping task, completed interval and overnight task retained their values.

### System notifications

[NotificationProbe.swift](NotificationProbe.swift) compiled together with **the actual production** `IOSReminderNotificationClient.swift`, `ReminderSound+Notification.swift` and built `OrbitCore.o` (including `ReminderSynchronizer`). Separate bundle `local.orbit.notification-probe` on the same **own Simulator**; no Orbit task store access. Authorization was accepted explicitly through the probe's native iOS dialog.

All queue checks passed against `UNUserNotificationCenter`, not a fake:

- Initial request, absolute UTC trigger instant.
- Rename and reschedule replace the request instead of duplicating it.
- Global silent sound replaces the queued sound.
- Complete, clear and delete remove pending requests.
- First alarm at +15 seconds invoked the real foreground notification delegate.
- Probe process terminated before the +45-second alarm. iOS displayed the `Terminated delivery` banner on the home screen while the process was absent.
- After relaunch, `deliveredNotifications()` contained both alarms and the pending queue was empty.

[Raw synthetic probe log](notification-probe.log). Foreground receipt 10:46:37 UTC; terminated delivery visible in CUA at approximately 10:47 UTC; delivered list read at 10:47:32 UTC. No synthetic remote push was used.

The probe exercises the production native adapter and synchronizer; its foreground predicate deliberately returns true. It does **not** prove the full Orbit task-editor/store-to-delivery path or foreground stale-task suppression. A separate actual-app store-to-delivery check is described below. Existing fake-client tests cover revisions/in-flight replacement, permission denial/retry, idempotency, foreign capacity, sound changes and completion/clear/delete races.

### Actual Orbit store → scheduler → delivery

The production Orbit app on the own Simulator was also tested separately from the probe. Its native notification permission was changed from denied to allowed in the Simulator Settings app; on returning to Orbit the denied warning disappeared without reinstalling or resetting its store.

`StoreDeliveryFixture.swift` compiles with the production core sources, accepts only the fixed own Simulator path, and adds two synthetic tasks after Orbit is terminated. [Fixture output](store-delivery-fixture.txt) records their UUIDs and absolute trigger instants. Original 17 tasks were retained, total became 19.

Orbit launched, read those persisted tasks and displayed **Запланировано: 2**. At 10:56:02 UTC the real **Orbit** foreground banner `QA · Orbit foreground delivery` appeared and the count became 1. Orbit was terminated at 10:56:11 UTC, before the second alarm's 10:56:47 UTC trigger. At 10:56:49 UTC CUA observed the real Orbit banner `QA · Orbit terminated delivery` on the home screen while its process was absent.

This is a store-to-delivery integration check; the fixture bypasses the creation form, so it does not claim a complete form-entry test.

## Remaining checks

- Physical-device delivery, sound/vibration and Focus/silent-mode behavior.
- Full continuous hold→body move→edge autoscroll→release, cross-day moves, and interruption with a finger down. CUA's available native API provides held clicks or drags separately, not a documented held-drag sequence; this report does not turn source review and resize checks into a claimed full gesture pass.
- Dense overlap geometry across both calendar views/themes, VoiceOver, and old iOS runtimes.
- Full actual-app reminder flow starting with form entry; the actual-app integration fixture exercises persisted store → scheduler → system delivery.

This stage is not installed on the physical iPhone and is not pushed. The previously installed redesign is `261ecc4`; main remains untouched.
