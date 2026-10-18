# NATIVE-UI-POLISH

Base8f39a8b. Task menu keeps instantaneous modal presentation/dismissal but fades/scales its local hosted content over0.18s using UIKit allowUserInteraction/beginFromCurrentState; Reduce Motion uses0.1s fade only. Initial SwiftUI animation attempts were suppressed by the disabled modal transaction; final UIKit version was verified on actual recorded frames (faint→opaque), not inferred from source.

TaskReminder.suggestedDate maps valid civil date/time in supplied/current Gregorian timezone to start−600s; missing/invalid/nonexistent DST times fall back to rounded now+1h. Only enabling seeds a new local reminder draft; existing persisted reminders remain independent and unchanged on interval/date edits. Both create form and existing-task reminder editor pass current planning values. A past scheduled seed stays exact and existing past-time hint/validation requires correction before save.

Shared NativeModeHeader zIndex10 keeps deformed glass above subsequent siblings. Today List date moved from a small list row to title2 semibold heading below controls, including empty state; removed redundant empty-state date and list top margin.

Checks: full125 core tests/16 suites PASS, including two new timezone/midnight/fallback/DST tests. Final Simulator and signed device builds PASS, diff --check clean. CUA own simulator:10:05 task→enable reminder→summary09:55; permission accepted only on own simulator, no save (Cancel). Today List large date + tighter content visually inspected. Final menu video frame sequence shows gradual fade/scale; rapid consecutive task/outside clicks leave no menu in full AX. Earlier SwiftUI-only recordings do not count as successful animation evidence.

Evidence outside repo: orbit-outputs/NATIVE-UI-POLISH/menu-uikit.mov, uikit-appearance.jpg, icon.mov. Icon drag recording does not reproduce the physical finger deformation from the user's screenshot; z-order fix implemented but that exact physical clipping case remains UNVERIFIED. Device install is not physical interaction QA. AXL/dark/VoiceOver/ReduceMotion GUI and existing-reminder edit persistence not repeated. No personal store access, no push/merge in this task.
