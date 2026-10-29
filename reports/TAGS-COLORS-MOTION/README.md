# Tags, colors and motion

## Implemented
- Projects → Tags: create, rename, seven colors, task counts, edit/delete menu and swipe deletion with confirmation.
- Deleting a tag removes its references from tasks without deleting the tasks. Task undo is cleared to avoid restoring stale tag references.
- Optional persisted color supports existing tags and backup v3 files without a color field. New tags default to coral.
- Short local animations for tag selection/palette/list changes, subtask insertion, form disclosure and undo-banner visibility. Reduce Motion disables these additions.

## Verification
- Simulator build succeeded; 153 core tests in 26 suites passed.
- Tests cover color persistence/reopening/backup, legacy backup decoding, duplicate rename rejection and deletion preserving tasks.
- Orbit Productivity QA synthetic simulator: existing store opened, blue tag created and reopened with blue selection preserved. Editor title, save/cancel and palette visible with keyboard.
- Physical iPhone delivery and full theme/Dynamic Type matrix not performed for this batch. Deletion verified at model level; destructive UI confirmation not submitted during GUI verification. Animation feel requires device review.

No personal database, TestFlight release or unrelated dirty documentation was changed.
