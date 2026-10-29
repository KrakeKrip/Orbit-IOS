# Tag editor polish

- Replaced grouped tag card with compact plain rows and themed background.
- Editor uses the same semantic canvas/surface and 16 pt corner treatment as task forms.
- Removed medium/large detent switching on keyboard appearance; editor has one large detent and a full safe-area background.
- Added explicit keyboard Done and interactive dismissal. Palette, save/cancel and persistence unchanged.

Validation: simulator build succeeded. On Orbit Productivity QA opened an existing tag, showed keyboard, dismissed using Done, and inspected resulting screenshot: uniform ivory background, stable expanded sheet, preserved blue selection. User recording reviewed. Physical dark-theme reproduction and installation not performed in this batch; no claim about all OS compositor frames.
