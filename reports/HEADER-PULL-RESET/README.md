# Header pull reset — 2026-10-30

Fixed the shared scroll observer so elastic header displacement is derived from the current native top boundary only during touch/tracking/deceleration. Programmatic calendar positioning and inset changes cannot retain a negative displacement at rest. Idle explicitly clears negative displacement even when no final geometry sample arrives. Elastic displacement is bounded to 80 points. Constant viewport/collapse reservations remain unchanged.

User explicitly requested no tests this time. No automated tests or Simulator interaction checks were run. Release device build succeeded; installed over local.orbit.ios on the paired iPhone without uninstalling or clearing its container. Physical gesture behavior still needs user confirmation. No model/schema changes. No TestFlight upload.

Private build/install logs: /private/tmp/orbit-header-pull-reset-build.log and /private/tmp/orbit-header-pull-reset-install.log.

## Follow-up: collapse delayed until 05:00

User reported the remaining absolute-origin error. DayTimelineView now opts into gesture-relative header progress: only user-driven vertical deltas update the bounded 0–80 point collapse range. Initial scroll-to-hour and programmatic positioning no longer determine header progress. At idle the header settles itself without sending the timeline to absolute offsets 0/80. Other list observers retain their existing behavior.

Release build and replacement iPhone installation succeeded. No automated or Simulator tests in this expedited fix; physical gesture confirmation remains with the user.

## Follow-up: midnight bounce and double separator

Calendar header deltas now clamp both geometry samples to the native top boundary; negative overscroll and its spring return no longer count as upward scrolling. At the top the header is expanded. Removed the internal untimed-section divider that duplicated the shared header edge.

Release build and device installation succeeded. No Simulator/automated tests in this continuing expedited correction; user-visible boundary behavior has not been independently verified.
