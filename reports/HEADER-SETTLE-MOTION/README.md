# Header settling motion — 2026-10-30

The supplied 15:42 screen recording showed abrupt settling between expanded and compact headers. The shared scroll observer now emits intermediate presentation offsets over 320 ms with cubic ease-out, keeping title, surface and layout in sync. A new touch cancels settling; Reduce Motion uses the endpoint directly.

Short-content scroll-phase idle handling remains a fallback when SwiftUI's simultaneous drag does not receive onEnded. Geometry updates do not start settling while the finger is moving. Calendar settling changes only the header, preserving timeline position. Long-content native scroll settling remains unchanged.

Validation: Debug Simulator build; manual compact/expanded endpoint checks in the dedicated Orbit Productivity QA Simulator. Physical-device smoothness and Reduce Motion interaction have not been verified. No phone installation, push or TestFlight upload in this task.
