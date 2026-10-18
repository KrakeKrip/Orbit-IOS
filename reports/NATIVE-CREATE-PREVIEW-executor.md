# NATIVE-CREATE-PREVIEW

Base2da807b. Calendar host passes create-sheet visibility into timeline. Successful gesture release freezes visual candidate and clears only active touch/autoscroll state; closing the sheet clears ghost. Failed/cancelled recognition, selection/day/disappear retain existing discard paths. Preview transition is identity without implicit animations; it remains noninteractive and never writes. Save still uses existing atomic create.

Checks: final Simulator and signed device builds PASS; diff --check PASS. CUA own simulator hold1000ms near10:05 opens10:05/30min form. simctl recording handoff.mov inspected as contact frames9.0–11.4sec: ghost stays painted on the grid in the partially presented sheet frame, no disappearance before modal. Cancel then repeated same hold opens again (no stuck draft). Title Плавный переход, fixed Add: calendar shows exactly one10:05–10:35 block with no dashed ghost after sheet closes. No core changes, prior123 tests not rerun for local UI lifecycle fix.

Evidence outside repo: orbit-outputs/NATIVE-CREATE-PREVIEW/handoff.mov, transition.jpg. Physical animation/haptics, AXL, dark theme, store failure retry not exercised. The frozen ghost uses the initial dragged interval while editing the form; it does not mirror subsequent form draft changes. Personal store never read.
