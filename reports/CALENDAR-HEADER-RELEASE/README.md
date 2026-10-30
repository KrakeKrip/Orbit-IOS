# Calendar header release

Calendar header motion now follows the drag independently of timeline content offset. Release settles to an endpoint; native gesture cancellation also settles rather than leaving a partial header. Short-content gestures subtract the recognition threshold so a small initial movement does not apply that distance in one frame. Native idle no longer restarts short-content settling with a different target.

Verification: inspected supplied 16:00 video as sampled frames; simulator interaction checked on Upcoming calendar and Projects during development. Final native-cancellation fallback requires physical interaction confirmation. Release build and device delivery recorded in the chat. No claim of exhaustive all-screen visual acceptance.
