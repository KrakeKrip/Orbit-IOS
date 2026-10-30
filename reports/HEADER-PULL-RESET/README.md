# Header pull reset — 2026-10-30

Fixed the shared scroll observer so elastic header displacement is derived from the current native top boundary only during touch/tracking/deceleration. Programmatic calendar positioning and inset changes cannot retain a negative displacement at rest. Idle explicitly clears negative displacement even when no final geometry sample arrives. Elastic displacement is bounded to 80 points. Constant viewport/collapse reservations remain unchanged.

User explicitly requested no tests this time. No automated tests or Simulator interaction checks were run. Release device build succeeded; installed over local.orbit.ios on the paired iPhone without uninstalling or clearing its container. Physical gesture behavior still needs user confirmation. No model/schema changes. No TestFlight upload.

Private build/install logs: /private/tmp/orbit-header-pull-reset-build.log and /private/tmp/orbit-header-pull-reset-install.log.
