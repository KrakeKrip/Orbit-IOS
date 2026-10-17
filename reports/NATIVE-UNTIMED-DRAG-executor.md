# R1 — отказ приёма на iPhone (2026-10-17)

Владелец прислал физический скрин: native lift работает, над сеткой знак запрета. Успешного drop в R0 нет — GUI gate остаётся открытым. Исправлены два lifecycle риска: delegate хранит live Binding к transient source (раньше let source снимался до onDrag и мог остаться nil в зарегистрированном target); transient scene inactive не отменяет token, background/day/project/disappear по-прежнему отменяют. Payload/дата/UUID/project/completion и одноразовая проверка перед save не ослаблены.

Device build BUILD SUCCEEDED (/private/tmp/orbit-untimed-device-r1.log), diff check PASS; core не менялся и4snap tests не повторялись. Исправление установлено update in place на iPhone по продолжающейся проверке ранее запрошенной сборки; личные данные не считывались. Фактическая причина отказа/успешный drop после R1 требуют повторного touch QA владельца — source исправления не подменяет физическую проверку. Main остаётся6b346ae, task не merge/push.

---

# NATIVE-UNTIMED-DRAG — реализация / открытый GUI gate

Статус REVIEW, не DONE. Ветка task/NATIVE-UNTIMED-DRAG, база6b346ae. Codex самостоятельно по прямому «давай». Main не меняется до проверки настоящего drag/drop. Phone/install/push не выполнялись.

## Изменения

Только4 iOS файла: shared CompactCalendarTaskRow title получает native onDrag; opensOnHold=false, короткий tap/popover и независимый completion-circle сохранены. Transient Codable payload token/taskID/day/project/completed/title, NSItemProvider с ownProcess visibility и отдельным UTType, не текст/внешний payload.

DayTimelineView onDrop/DropDelegate на CONTENT сетки (location должна включать реальный scroll offset), gutter исключён. Candidate через существующий TaskTimelineAdjustment: стартsnap5, начальная длительность30мин как create, civil end validation/2199 range. Ghost точной длительности и time label до отпускания; haptic tick только при смене snapped time. Preview не перехватывает input. Native dropExited очищает ghost, completion/invalid target не пишут.

После async provider decode повторно сверяются payload/token, текущий выбранный день, live source nil time/duration, project/completion; token потребляется единожды до синхронного model.setPlannedInterval → существующий atomic store save/rollback. UUID/date/project/deadline/reminder/title не заменяются. Day/project/phase/disappear сбрасывают transient token. После cancel не остаётся визуального selected-state или запрета tap; token может оставаться инертным до следующего drag/смены контекста. Анонимные CalendarDrag diagnostic notices отмечают start/target/drop без task данных.

Core/schema/store/manual editors/overlap layout не менялись. Создание пальцем/междневный drag/custom edge auto-scroll вне scope.

## Проверки

- iOS builds ×2 BUILD SUCCEEDED (вторая с lifecycle diagnostics). Единственный AppIntents metadata skipped warning, без code errors.
- Existing TaskTimelineAdjustmentTests4/4 PASS: snap5, bounds, resize rules, invalid/legacy, civil end/2199. Full112 не повторялись: core не менялся. Эти4 теста не доказывают UI координаты/жест.
- Own iPhone17/iOS27 Simulator1A3DE04B-CFDB-4DB4-BC3D-CB429529DF7A: создана через настоящий UI задача «На сетку», переход Today List→Calendar, source card/hint/ruler08:00 видимы. Обычный tap открывает прежний popover с title/date/actions, без исчезновения source.
- Попытки CUA drag/hold не дали успешного переноса. После update инструментарий возвращает noWindowsAvailable для координат и cannotClickOffscreenElement для timed AX click, хотя AX/screenshot доступны. Проверены rebind/expand/compact/Raise/reset CUA; ошибка остаётся. CalendarDrag start/target/drop notices отсутствуют, системный druid лишь warmed up. Это не подтверждение дефекта продукта и не подтверждение рабочего drag.
- Read-only synthetic store: ровно1 задача, plannedTime/duration nil; попытки инструмента не изменили её интервал. Это не полноценный тест cancel активного drag.

## Обязательный следующий gate

На реальном touch input: long-hold title → hover/time ghost → drop с тем же UUID/date и duration30; cancel вне grid/no writes; scrolled timeline pointer→правильное время; source из expanded bounded list; Today/Upcoming/project; stale context/completion/source rejection; повторный drag и короткий tap; near midnight/2199, ошибки save. До этого не merge как accepted. Haptics/AXL/VoiceOver/physical device не проверены.

Evidence /Users/atlhnv/Codex/orbit-outputs/NATIVE-UNTIMED-DRAG/:01-untimed-source.png,ios-build.log,snap-tests.log,system-drag.log,synthetic-source.json. Только синтетические данные; личные stores не использовались.
