## Текущий этап 2026-10-17 — перенос из «Без времени»

NATIVE-UNTIMED-DRAG REVIEW в отдельной task-ветке от6b346ae. Код4iOSfiles/build/4snapchecks PASS; short tap menu GUI PASS. CUA не доставляет drag и возвращает noWindowsAvailable; end-to-end drop/scroll/cancel НЕ проверены. Main не менять до touch QA. reports/NATIVE-UNTIMED-DRAG-executor.md. Phone/push/install не выполнены.

## Итог 2026-10-17 — общий звук

NATIVE-SOUND-001 DONE self-check:5общих вариантов/preview/persistence/pending replacement,112tests/iOSbuild PASS; real delivery после silent→drop с закрытым процессом и system playback именно orbit-drop.wav. Schema не менялась. iPhone sound QA/AXL/VoiceOver отдельно. reports/NATIVE-SOUND-001-executor.md. User подтвердил работу предыдущей установленной версии; новый sound build не устанавливался/push не выполнялся.

## Итог 2026-10-17 — локальные напоминания

NATIVE-REMINDER-001 DONE по Codex self-check на own Simulator: core110/upgrade/build PASS; real notification при завершённом процессе подтверждён AX/screenshot. Прежний системный отказ не повторился после reboot Simulator, точная причина не установлена. iPhone/звук/VoiceOver ещё не проверены. reports/NATIVE-REMINDER-001-executor.md заменяет прежний runtime-blocked статус ниже. Push/install не выполнялись.

## Сохранённый этап 2026-10-17 — напоминания

NATIVE-REMINDER-001: NEEDS_FIXES, task branch от 7971d3f. Core110/110 и iOS build PASS; реальная доставка отклоняется системным API на двух own Simulator. Причина не установлена. Пользователь попросил завершить проход; main не менять до runtime gate. reports/NATIVE-REMINDER-001-executor.md.

## Последний этап 2026-10-16 — независимый дедлайн

NATIVE-DEADLINE-001 выполнен Codex по прямому «делаем»: optional civil deadlineDate, atomic create/edit/clear, shared UI и overdue со следующего дня только для open. Core104/104 с actual previous-source upgrade, iOS build и own Simulator GUI PASS; ограничения reports/NATIVE-DEADLINE-001-executor.md. Notifications/reminders следующим отдельным этапом. Личные данные/телефон в QA не используются, автоматический push/install этого этапа не выполняется.

## Текущая работа 2026-10-16 — папки проектов / общий Settings

PRJ003/004 выполнены Codex (self-check): принадлежность задач, проектные List/Calendar, общий Settings и нижний «+». Core101/101, previous-source upgrade, финальная iOS-сборка и живой GUI PASS. CUA после восстановления окна снова доставляет действия; прежний блокер закрыт. Подробные сценарии и ограничения — reports/NATIVE-PRJ-003-004-executor.md. Вибрация на физическом устройстве ещё требует проверки владельца.

## Последний этап 2026-10-16 — NATIVE-PRJ-002

По «делаем» Codex выполнил вкладку Проекты и shared-store create/rename UI. Self-check: iOS builds + synthetic Simulator Cyrillic/validation/Cancel/tab/dark/AXL/relaunch и read-only store diff PASS. Core/schema не менялись, предыдущие98 tests не повторялись. Swipe не доставляется CUA — UNVERIFIED. reports/NATIVE-PRJ-002-executor.md. Следующий маленький core scope tasks/NATIVE-PRJ-003.md; GLM не назначен. Личный iPhone/push не выполнялись.

## Актуальный статус 2026-10-16

Пользователь разрешил продолжить очередь, замечания UI передаст отдельно. Codex самостоятельно выполнил NATIVE-PRJ-001 (core проектов, без UI/assignment), self-check: 98/98 core, previous-source disk upgrade, iOS build PASS. Отчёт reports/NATIVE-PRJ-001-executor.md. Следующий bounded scope подготовлен в tasks/NATIVE-PRJ-002.md; GLM сейчас не назначен. Историческое «schema/core не менять» ниже относится к UI-FEEDBACK scope и не запрещает явно назначенный PRJ001 additive upgrade. Личные stores/iPhone не использовались; автоматический push и установка этой schema-версии не выполнялись.

## Актуальный статус 2026-10-15

Пользователь подтвердил запуск Orbit на личном iPhone после NATIVE-DEVICE-001. Это подтверждение запуска, не полный physical smoke. По прямому поручению пользователя Codex самостоятельно выполняет NATIVE-UI-FEEDBACK-001: интерфейс и баги из пользовательского ZIP. GLM сейчас не назначен. Core/schema/личные данные/подпись не менять; крупные функции из архива сохранены в docs/NATIVE-FEEDBACK-BACKLOG.md. Подробности проверок и ограничения — reports/NATIVE-UI-FEEDBACK-001-executor.md. Полный физический smoke, haptics и hold остаются отдельной проверкой владельца. Reports в файл, чат коротко.

# Orbit — правила координации

Этап NATIVE LOCAL-FIRST, 2026-10-12. Пользователь сменил приоритет на локальные SwiftUI приложения iOS/macOS без сервера и синхронизации в первом прототипе. Web TASK-001–008 DONE и сохранены; TASK-009A PAUSED, прежняя web очередь не активна. NATIVE-003 и NATIVE-004 завершены; NATIVE-005 завершён; NATIVE-006 принят; NATIVE-007A принят; назначена только tasks/NATIVE-UI-MODE.md в отдельном task worktree. Root PRODUCT/ARCHITECTURE/DESIGN/TASKS — новые актуальные native требования; docs/web-baseline-2026-10-12 — исторические документы.
GLM работает только в назначенном отдельном worktree и выполняет один TASK.

## Роли и источники требований
- Пользователь утверждает продуктовые решения и передаёт задания между агентами.
- Codex: архитектура, документация, TASK, независимый review и локальная интеграция.
- GLM: реализация только назначенного TASK, самопроверка, обычные коммиты и отчёт.
- Прямые актуальные инструкции пользователя имеют приоритет. Далее AGENTS.md определяет процесс; PRODUCT.md — поведение, ARCHITECTURE.md — технические контракты, DESIGN.md — интерфейс. TASK ограничивает объём; при конфликте исполнитель возвращает BLOCKED, а не расширяет задачу.
- CODEX_PROMPT.md сохранён как исторический документ; его поручение реализовать Milestone 0 целиком больше не действует.
- План архитектуры не является подтверждением реализации. Изменения архитектуры согласуются с Codex и фиксируются в DECISIONS.md.

## Один TASK — одна ветка — один worktree
Размер новых заданий: один конкретный проверяемый результат, небольшой scope. По уточнению процесса после жалобы пользователя на медленный темп (2026-10-09), один и тот же дефект в 2–3 файлах можно закрывать одним небольшим TASK. Не объединять новые API/UI/бизнес-правила или большую переработку контроллеров. После коррекции — релевантные targeted checks; full gates — перед итоговой приёмкой, без повторов без новой причины. Блокирующие ошибки исправлять сразу, мелкую уборку собрать в финальный проход. Web очередь PAUSED; NATIVE-004/005 приняты, Today list принят; назначен маленький read-only core helper NATIVE-007A, назначен только grid UI007B в трёх iOS файлах, без core changes. Native задания также маленькие, shared Swift core не означает проверенный iOS target. Огромные задания для GLM Flash по-прежнему запрещены.

1. Codex фиксирует координационные документы и базу сравнения, создаёт task/TASK-NNN и отдельный worktree вне исходников.
2. Пользователь передаёт GLM путь и TASK. Локальный worktree доступен лишь исполнителю на том же компьютере; облачная доступность не подразумевается.
3. GLM проверяет корень Git, ветку и status перед изменениями. При чужих изменениях останавливает затронутую работу. Для NATIVE-001 pre-existing untracked Swift starter явно разрешён в tasks/NATIVE-001.md, сохранён coordinator snapshot; новые неожиданные изменения вне snapshot не перезаписывать.
4. GLM делает обычные новые коммиты и возвращает READY_FOR_REVIEW либо BLOCKED, ветку, полный SHA, изменения, фактические проверки и ограничения.
5. Codex проверяет все коммиты от указанной базы, scope, ownership, ошибки и критерии; самостоятельно запускает релевантные проверки.
6. Замечания: NEEDS_FIXES, reports/TASK-NNN.md, исправления в той же ветке новыми коммитами.
7. После успешного review: локальный merge --no-ff в чистую main, интеграционные проверки, статус DONE и отчёт. Следующий TASK только после приёмки или явного приостановления. По прямому уточнению пользователя2026-10-13 после приёмки сразу готовить следующий небольшой TASK/worktree и выдавать GLM prompt в файле и коротко в чат, без дополнительного запроса «что дальше».

Статусы: TODO, IN_PROGRESS, REVIEW, NEEDS_FIXES, BLOCKED, DONE.
TODO означает в том числе подготовленную, но ещё не запущенную задачу.

## Формат отчёта исполнителя
Подробный отчёт GLM сохраняет в reports/TASK-NNN-executor.md. В чат только 4–5 коротких строк: статус, full SHA, итог, целевые checks и путь к отчёту. Не выводить подробный отчёт в чат. Прямое указание пользователя от 2026-10-09.

## Ограничения
- Codex не реализует продуктовые задачи за GLM без прямого указания пользователя.
- GLM не меняет корневые координационные документы без явного scope; отчёт исполнителя — reports/TASK-NNN-executor.md, отчёт review — reports/TASK-NNN.md.
- GLM не делает merge, rebase, amend, reset, force push и не меняет другие ветки.
- Push, deployment и изменение действующих серверов требуют отдельного разрешения. Не изменять VPN и сторонние проекты.
- Не удалять пользовательские файлы, не перезаписывать чужую работу, не делать автоматический stash, не переписывать историю.
- Не коммитить секреты, .env, реальные персональные данные и дампы. Не запускать миграции против неизвестной или production БД.
- Не считать сборку доказательством GUI, авторизации или работы на реальном устройстве. Явно отделять проверенное от непроверенного.

## Активные native проверки

NATIVE-001: swift build/swift test, disk reopen и actual macOS GUI evidence на own temp store. Только native code/документы в scope; web/DB/auth suites не повторять без изменений веб-кода. Xcode уже установлен: использовать DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer для native команд, системный xcode-select не менять. Реальная iOS проверка требует соответствующего tooling; непроверенное явно помечать.

## Исторические web проверки
TASK-001 добавил package.json, npm scripts dev/start/lint/typecheck/test/build и README. Целевой runtime Node 24 LTS. Review — reports/TASK-001.md; тесты foundation не подтверждают будущие DB/auth/task flows.
Дальнейшие проверки соразмерны изменениям: правила дат — unit, безопасность — integration с двумя пользователями, интерфейс — browser/E2E и мобильные размеры.

TASK-002 добавил test:e2e (production build + Chromium). Для независимого запуска: CI=1 E2E_PORT=<свободный loopback port> npm run test:e2e; CI=1 исключает reuse стороннего сервера. После TASK-002 текущая регрессия: 4 Vitest и 47 browser tests. Проверки интерфейса не подтверждают auth/DB.

TASK-003 добавил PostgreSQL/Drizzle schema и миграции; npm run test:db — отдельная local PostgreSQL suite: 47 tests (28 schema,15 guard,4 runner), TEST_DATABASE_URL явный, namespace orbit_test, per-run unique DB/fixture без удаления существующих БД. Production build/UI tests по-прежнему не требуют env/БД. Auth flows/CRUD ещё отсутствуют. Audit/tooling ограничения и review — reports/TASK-003.md.

TASK-004 принят после R1/R1b/R2/R3/R3b/R3c: 4 UI/47 DB/31 auth/56 browser checks, настоящий CLI PTY и аварийный E2E exit-status проверены. Main build без env PASS; runtime auth требует env и bootstrap. Auth/E2E только собственные unique DB, фактический app pool закрывается до DROP; completion result связывает shutdown status с итогом runner. Review — reports/TASK-004.md. TASK-005 settings persistence принят, review — reports/TASK-005.md.

TASK-005 DONE: GET/PATCH /api/v1/settings, account defaults UTC/system, owner-scoped field-specific upsert, IANA validation, account theme bridge и Settings UI. Main 15 pure/UI/47 DB/51 auth/63 E2E и build без env PASS. Delayed response/account switch/timezone pending и реальный dev StrictMode success/error проверены. Реальные устройства/production не проверены; timezone алгоритмы расписания и CRUD — следующие TASK.

TASK-006 DONE: owner-scoped project service и GET/POST collection, GET/PATCH item, реальный /projects с active/archive, Unicode names и pending rename guard. Main 29 unit/47 DB/72 auth/71 E2E и no-env build PASS; review — reports/TASK-006.md. Archive сохраняет связанные tasks; project task list/delete/reorder/sharing вне scope. Реальные устройства/deployment не проверены.

TASK-007 DONE: tasks API/service с owner-scoped transactions, completion journal/no-op/reopen/soft delete; Inbox quick-add/rename/complete/reopen/delete confirmation. Read/network errors отделены от write outcomes; pending actions и keyboard focus/error/cancel/retry проверены. Main 44 unit/47 DB/101 auth/83 E2E и no-env build PASS. Dates/notes/priority/project assignment/subtasks/recurrence UI ещё отсутствуют; реальные устройства/deployment не проверены. Review — reports/TASK-007.md.

TASK-008 DONE: civil planning и shared schedule editor, Today mutually exclusive ranks и raw API/UI ordering, Upcoming7 с безопасными границами, server account timezone labels. Независимо Node24/PG18.6: 69 unit/47 DB/124 auth/123 browser, lint/typecheck/no-env build PASS; auth UTC/Moscow matrix PASS. PG17 был недоступен; реальные устройства/production не проверены. Источники merge проверены идентичными протестированному task-tree; main lint/typecheck/69unit PASS. Push/deploy не выполнялись.
