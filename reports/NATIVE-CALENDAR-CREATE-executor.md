# NATIVE-CALENDAR-CREATE — self-check

Implemented in task/NATIVE-CALENDAR-CREATE from f7a67b5. Empty calendar lane: hold 0.45 s creates local 30-minute preview; vertical movement adjusts duration in 10-minute steps, minimum 5, start snaps to 5. Release opens existing create form with date/time/duration/project presets. No write until existing explicit submit (Add or keyboard Done); Cancel discards. Manual editor precision, schema and existing interval writes unchanged. Creation stays within the selected civil day; edge autoscroll/cross-date gestures remain separate work.

## Validation
- Full OrbitCore suite: 122 tests / 16 suites PASS, including three creation tests with invalid input and boundary sweep.
- Final Simulator and signed device builds: BUILD SUCCEEDED. diff --check PASS.
- Real CUA GUI on own orbit-untimed-codex simulator: calendar scrolled to 08:00 at top; stationary hold near visible 11:00 opened create form with 2026-10-18 / 11:05 / 30 minutes and end 11:35. Cancel: full serialized ZORBITTASK rows identical before/after.
- Second hold, Cyrillic title Жест календаря, keyboard Done submitted through existing onSubmit. Store contains exactly one new row, date 2026-10-18, time 11:05, duration 30; all three original synthetic rows unchanged. Calendar block 11:05–11:35 visible; terminate/relaunch AX confirms title/interval retained.
- Screenshot visually inspected: orbit-outputs/NATIVE-CALENDAR-CREATE/created.png (outside repository). Test store is synthetic; personal phone store never read.
- Signed final app installed in place on iPhoneAtl: devicectl success, database sequence 2636. No uninstall, migration or data reset.

## Limits
Continuous hold-and-drag resizing, ordinary scroll conflict, existing move/resize gesture regression, project preset GUI, dark theme, AXL, VoiceOver and physical haptics are UNVERIFIED in this pass. Snapping/duration boundaries are covered by core tests, not a physical gesture demonstration. Initial sequenced recognizer did not capture stationary holds and was replaced by simultaneous long-press + drag; successful GUI evidence is from final implementation. Phone installation is not physical interaction QA.
