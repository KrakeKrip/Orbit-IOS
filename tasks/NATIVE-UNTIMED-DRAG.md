# NATIVE-UNTIMED-DRAG — из «Без времени» на сетку

REVIEW (GUI gate открыт), Codex самостоятельно по «давай», база6b346ae. Только native iOS Day Calendar (Today/Upcoming/project shared screen). Удержание title/card начинает локальный drag; completion circle и короткий tap/menu сохранены. Drop на временную область назначает выбранный civil day, старт snap5, начальная длительность30мин как в create. Существующие interval/store/end helpers, UUID/project/deadline/reminder не меняются. Preview по реальным content coordinates (учёт scroll offset), tick при смене snapped time. Отмена/выход/недействительный target не пишут; state/day/source revalidated перед единственным save. 2199 overflow отказ. Внешние drags не принимаются.

Без создания новых задач, переноса между днями, кастомного edge auto-scroll, переделки overlap, schema и ручных editors. Relevant existing core tests/build + own Simulator GUI, ограничения явно в отчёте. Phone/push не входят.


Реализация/сборка и4targeted core checks PASS; CUA drag не доставляется, затем noWindowsAvailable. Успешный drop/scroll/cancel остаются UNVERIFIED. Не merge как accepted до touch QA. reports/NATIVE-UNTIMED-DRAG-executor.md.

R1: physical screenshot показал forbidden drop. Delegate.source заменён snapshot→live Binding, phase cancel только background. Device build PASS, исправленная сборка установлена владельцу; успешный touch drop ещё ожидает проверки. Main не merge.

R2: стандартный opaque NSString nonce, viewport target + измеренный scroll origin; R1 не прошёл touch QA владельца. По новому запросу добавлено сохранение List/Calendar отдельно Today/Upcoming/каждый project через AppStorage. REVIEW до успешного native drop.

R3: после подтверждённого native lift/drop владелец выявил неверный час при scroll. Offset теперь из global frames viewport/content через onGeometryChange; build PASS, physical scroll/drop QA ожидается.

2026-10-17 расширение по прямому запросу: hold/move timed блока в верхнюю область очищает interval без смены даты; общий date picker Upcoming List/Calendar с маркерами plannedDate. Детали и GUI ограничения reports/NATIVE-CALENDAR-RETURN-MARKERS.md. REVIEW до touch QA.
