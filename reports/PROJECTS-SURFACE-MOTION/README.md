# Projects surface and native motion

Removed tag explanatory footer entirely. Projects/tags use themed inset sections, compact empty rows and section-local creation controls. Shared floating + still creates tasks.

Replaced fixed custom page header with native large navigation title and toolbar. The list uses native always-enabled bounce so short content responds to scrolling; navigation title can collapse with scroll. No custom spring applied to calendar gestures or date wheels.

Validation: Simulator build succeeded and synthetic UI inspection confirmed both sections, themed surfaces, no footer stripe, task FAB and actions. Physical motion feel and dark-theme screenshot not verified in this batch. This implements motion on Projects; other screens have not been converted to collapsing native headers.
