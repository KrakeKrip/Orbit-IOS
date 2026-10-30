# Short-screen header gestures

## Problem
Removing artificial scroll space correctly stopped blank scrolling, but header collapse still depended on changes in content offset. A short List reported gesture phases without useful offset changes.

## Change
The shared main-scroll observer tracks vertical finger translation independently when the content fits the viewport. Header movement is bounded and settles expanded or compact after release. Horizontal gestures do not start this handling. Long lists and calendar timelines retain their existing scroll paths; no invisible footer is added.

## Verification
- Debug Simulator build passed.
- Manual GUI checks on Orbit Productivity QA (iPhone 17, iOS 27): short Projects collapses upward and expands downward; empty Upcoming list does the same, including a repeated upward swipe.
- Physical iPhone installation and physical touch behavior have not been verified in this change.
- No TestFlight upload or GitHub push.
