# Task editor dismissal and motion

Reviewed supplied recording: Form row expansion stretched wheel layout and surrounding rows. Removed inherited layout animation from parameter forms; native navigation transitions remain.

Added Close on each parameter page, routed to the root draft cancellation. Changed drafts prompt Continue editing / Discard; unchanged drafts close directly. A presentation delegate reports blocked interactive dismissal attempts to the same confirmation instead of only bouncing the sheet.

Validation: Simulator build passed. Opened new task → Time → Close; confirmation showed both actions, Continue returned to editing. Physical swipe gesture and all animation frames are not yet verified on iPhone. No model/schema changes, no physical installation in this batch.
