# R3 — позиция на прокрученной сетке (2026-10-17)

Владелец подтвердил native drag после R2, но ghost/вибрация начинались с полуночи при прокрутке к 12–21. Named coordinate space на ScrollView не дал нужного смещения. Удалены PreferenceKey и замер в этой системе координат. Теперь content и внешний viewport измеряются в одной `.global` системе; offset = viewport.minY − content.minY, candidateY = drop.location.y + offset. Offset читается через live binding на каждом dropUpdated/performDrop. Например, при viewport=200/content=-568 (12 часов ×64pt) dropY=192 даёт15:00, а не03:00. Ghost/haptic и окончательный commit используют один candidate.

Сначала проверен onScrollGeometryChange, но compiler выявил iOS18-only при deployment17; заменён на back-deployed onGeometryChange без повышения target. Финальный device build BUILD SUCCEEDED (`/private/tmp/orbit-untimed-device-r3.log`). Core/schema/store/snap5/30min/сохранение вида не менялись; unit core повторно не запускались. Touch QA на прокрученной сетке после этого изменения пока UNVERIFIED, gate REVIEW остаётся. Ниже история предыдущих попыток.

---

# R2 — повторный отказ и сохранение вида (2026-10-17)

R1 не решил перенос по фактической проверке владельца. Статус REVIEW: успешный touch drop не подтверждён, main не merge.

Транспорт заменён на стандартный NSString с одноразовым UUID. Данные задачи остаются только в памяти; внешний текст без совпадающего активного nonce не может изменить задачу. Регистрация target больше не зависит от source, который появляется позже при onDrag. Предложение copy относится только к передаче nonce: существующий UUID обновляется, новая задача не создаётся. Guard перед save сохранён.

Drop target перенесён с длинного content на видимый ScrollView. Координата времени вычисляется из viewport location минус измеренный content origin (scroll offset), gutter/вне viewport отвергаются. Это новая попытка устранить отказ, не установленная по скриншоту первопричина.

По новому запросу: Today/Upcoming используют отдельные AppStorage mode keys, проекты — ключ с UUID проекта. Сохраняется только List/Calendar, выбранный день/вкладка не меняются. Schema/core/store не тронуты.

Device и Simulator builds BUILD SUCCEEDED (`/private/tmp/orbit-untimed-device-r2.log`, `/private/tmp/orbit-untimed-ios-r2.log`), diff --check PASS. R2 установлен update-in-place на iPhone, bundle local.orbit.ios; личный store не читался. Единственный build warning — AppIntents metadata extraction skipped (нет зависимости AppIntents). Persistence через relaunch и успешный drop на реальном устройстве пока UNVERIFIED; предыдущие 4 core snap tests не доказывают native gesture. Ниже — исторические R1/R0 отчёты, их transport/content-target описание заменено этим R2.

---

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
