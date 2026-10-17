# Компактнее строки и фон диапазона — 2026-10-17

Прямой запрос владельца по двум physical screenshots. Shared InboxRowView заменяет внутренний vertical padding2 и стандартные List insets на явные top/bottom4pt (leading/trailing16). Поэтому изменения применяются к Inbox/Today/Upcoming/project list через переиспользуемую строку. Title остаётся multiline natural height; metadata date/time/deadline/reminder и min44pt body/completion hit areas сохранены, fixed height не вводилась. Размеры календарных chips/interval blocks не менялись.

Upcoming List rangeCaption row получил listRowBackground(appearance.canvas), как остальные строки: белая системная подложка заменена на текущую theme canvas, включая ivory/dark/OLED.

Targeted device BUILD SUCCEEDED /private/tmp/orbit-list-compact-theme.log, diff --check PASS. Core/schema/поведение меню не менялись, tests не добавлялись/не повторялись для этого обратимого UI изменения. Physical visual height/theme и AXL после правки ещё UNVERIFIED; по source multiline/44pt preserved. Main/push не выполнялись. После build изменён только комментарий строки, исполняемый код совпадает со сборкой.
