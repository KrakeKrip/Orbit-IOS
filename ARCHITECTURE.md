Актуально2026-10-13: NATIVE-007A принят — read-only TaskDayProjector проецирует interval на selected civil day, UUID/day identity, minutes0...1440; positive overnight continuation и exact-midnight exclusion. Геометрия/lane rendering в UI ещё не реализованы.

Актуально2026-10-13: NATIVE-006 принят: native Today/Inbox TabView используют один IOSInboxModel/store; Today read-only plannedDate==local Gregorian today, day пересчитывается appear/active/periodic30s. Store/model/schema не менялись. Calendar overnight projection/grid отдельно. Реальный iPhone и runtime error banner не проверены.

Актуально2026-10-13: NATIVE-002 интегрирован как локальная iOS база (apple/OrbitIOS + OrbitCore), main build/core20 PASS. NATIVE-001-R1 остаётся открытым для macOS CLI, iOS его resolver не вызывает. NATIVE-003 принят: nullable plannedDate civil Gregorian string, explicit save и проверенная миграция прежнего store; UI adapters фиксируют Gregorian calendar, сохраняя локальную timezone. GUI смены даты и реальный iPhone остаются непроверенными. Sync/server/полный календарь не входит. Историческое условие «NATIVE-002 после приёмки NATIVE-001» ниже заменено прямым разрешением пользователя iOS первым.

# Orbit — активная native архитектура

2026-10-12: пользователь выбрал native/local-first. Прежняя web архитектура сохранена в docs/web-baseline-2026-10-12/ARCHITECTURE.md; Next.js/PostgreSQL/Better Auth код не удалён и не переписывается. Он не нужен для запуска native прототипа.

## Стек и границы

Swift + SwiftUI, локальное SwiftData хранилище. Начальная техническая база macOS14+/iOS17+, окончательный минимум пересмотреть при подготовке iOS target по устройствам пользователя. SwiftData ModelContainer с явным cloudKitDatabase:.none: без CloudKit/сервера/аккаунта. Sync позже отдельное архитектурное решение; не обещать, что текущая схема автоматически решит конфликты/миграцию в облако.

Native код в apple/Orbit/, отдельный Swift package: OrbitCore (минимальная модель и disk store), OrbitMac (SwiftUI app entry и Inbox), OrbitCoreTests. Core не зависит от AppKit/HTTP/веб-кода и пригоден для будущего iOS target. Не создавать repository/protocol/service слои без конкретной необходимости. Не добавлять все будущие сущности заранее.

NATIVE-001 — один вертикальный срез create/complete/reopen+disk persistence в macOS Inbox, без проектов/scheduling/rename/delete. Для SwiftPM executable допускается документированный launch через swift run OrbitMac; Xcode project/iOS app target — отдельный NATIVE-002 после приёмки NATIVE-001; Xcode уже установлен. Нельзя заявлять, что shared source означает проверенную iOS сборку.

Local store path централизован; для tests/GUI review явно отдельный temp path. App startup не удаляет/пересоздаёт повреждённый store. Mutation success только после явного save; failure не теряет draft и не считается записанным. Stable UUID для объектов, версия schema меняется осознанно, пользовательские stores не используются в tests. SwiftUI/SwiftData main actor boundaries простые и явные, без sync engine/HTTP/dependency frameworks.

## Tooling и проверка

Окружение подтверждено2026-10-13: /Applications/Xcode.app (Xcode27.0), macOS/iOS SDK, iOS27.0 runtime и список Simulator devices доступны. System xcode-select остаётся CLT; для команд использовать DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer, без глобального переключения. Native iOS Inbox проверен build/Simulator в NATIVE-002, реальный iPhone пока не проверен; baseline iOS17 runtime не проверен.

swift build / swift test на macOS, disk reopen regression; реальный GUI create/complete/reopen/relaunch на собственном synthetic store. Compile/unit/UI/device evidence разделять. Web full gates на каждом native задании не запускать, пока web код не меняется.

## Официальные источники

- SwiftData ModelContainer: https://developer.apple.com/documentation/swiftdata/modelcontainer
- Явный disk URL/configuration: https://developer.apple.com/documentation/swiftdata/modelconfiguration
- Отключение sync: https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/none
- Simulator требует Xcode: https://help.apple.com/xcode/mac/current/en.lproj/devfd9e28378.html

## Временной интервал, принятый NATIVE-004

Два nullable поля plannedTime HH:mm и durationMinutes1..1440 требуют plannedDate, pair всегда оба nil либо оба установлены. Это wall-clock/civil interval, без UTC instants/timezone offsets. Pure helper derive end; crossing midnight допускается, end не хранится и должен помещаться в1900–2199. Прежний clearDate очищает pair одним save, date move сохраняет валидную pair. Shared core принят: core50/iOS build/legacy upgrade и независимый civil oracle PASS. iOS editor принят NATIVE-005 после title correction; calendar rendering позже. Любая additive schema проверяется по own fixture реальной предыдущей версии, без reset stores.

## Navigation/view separation,2026-10-14

Bottom sections Today/Inbox/Upcoming, Calendar не отдельная section. Today/Upcoming containers имеют собственный list/calendar presentation state над общим IOSInboxModel/SwiftData store. Accepted DayTimeline/TaskDayProjector/compact untimed UI reuse, без новой persistence entity/cache/клонов данных. Same task identity/mutations/errors across views. Today local current date обновляется lifecycle/clock как accepted TodayScreen; Upcoming selected civil day/range независим, сохраняется при view switches. Navigation migration не требует schema migration/network. No nested NavigationStacks при embedding existing screens; минимум local UI extraction по реальной необходимости. Последовательные boundedNAV001(Today mode/remove Calendar tab),NAV002(real Upcoming list/calendar) без fake empty tabs, full3days/Month ещёfuture.

## Назначенный NATIVE-MIN5: write minimum vs legacy read

Новая запись/изменение interval —5…1440; уже существующие1…4 остаются вstore/end/projector и не мигрируются автоматически. Отдельный маленький writevalidator вacceptedTaskTimeInterval, storeprecheck beforemutation; pureend/isValidDuration сохраняютreadcompatibility1…1440. Schema неизменна, minimumнеравенкратности5, clear/dateMove/complete legacydataпрежние. Это назначенныйконтракт, доreviewнеimplementedPASS.

## Локальная основа проектов, NATIVE-PRJ-001 (2026-10-16)

OrbitProject добавляется в тот же ModelContainer рядом с неизменённой OrbitTask. UUID/name/createdAt, validated list/create/rename через OrbitTaskStore; отдельный OrbitProjectStoreError не меняет task error enum и его UI switches. Существующий task-only store обновляется SwiftData additive migration, без reset/пересоздания. Assignment/relationship, удаление проекта и UI не входят в этот этап. Проверка upgrade обязательна до интеграции; downgrade старым бинарником не поддерживается.

## PRJ003/004 — проектные папки (2026-10-16)

OrbitTask.projectID — optional UUID с nil для upgrade; assignment через store, не SwiftData relationship/cascade. Store валидирует project existence до insert/mutation, nil clears, identical no-op, один save/rollback. CalendarDayScreen принимает optional projectID/header, projector получает filtered tasks; source UUID callbacks по-прежнему shared. ProjectWorkspaceScreen владеет selected day/mode и не создаёт другой store или nested NavigationStack. Общий create sheet получает preset project, локальный draft и whole-candidate save. Непроектные views не фильтруются автоматически. Живой GUI gate завершён на собственном Simulator, ограничения в отчёте. Floating action placement общий для task/project create; в индексе проектов создаётся проект, внутри папки задача.

## Дедлайн (NATIVE-DEADLINE-001)

OrbitTask.deadlineDate — optional Gregorian civil YYYY-MM-DD 1900–2199; добавляется без сброса старых записей. Валидация TaskDeadline перед insert/mutation, один save/rollback; setDeadlineDate identical no-op. Это независимый срок до конца дня: ни plannedDate/time, ни projectID, ни membership, projector, gestures не меняются. Просрочка: незавершённая задача с deadlineDate < local today. Сегодняшний срок ещё не просрочен; completed хранит срок без overdue. UI badge обновляется раз в минуту без записи. Общая create форма сохраняет целый candidate, редактор использует local draft и явные Save/Cancel/clear. Для tiny блоков полный срок доступен через меню, геометрия длительности прежняя.


## Локальные напоминания — NATIVE-REMINDER-001

OrbitTask.reminderAt — optional Date, абсолютный whole-second instant в UTC1900…2199. Nil при additive upgrade. Отображение/ввод в текущем часовом поясе; смена planned date/time, deadline или проекта не переносит reminder. Create валидирует whole candidate до insert, edit — до mutation, один save/rollback. Завершение сохраняет конфигурацию, но отменяет уведомление; reopen планирует только ещё будущее время.

ReminderPlanner/ReminderSynchronizer работают с value snapshots без SwiftData объектов через await. Serial revision worker удаляет stale async add, обновляет стабильный orbit.reminder.UUID по title/fireAt, не затрагивает чужие identifiers. Консервативный pending budget64 включает чужие запросы; хвост очереди требует последующего открытия Orbit для пополнения. Это не обещание неограниченного background scheduling.

IOSReminderNotificationClient — public UserNotifications API: native permission, UTC calendar trigger, default sound, foreground delegate. Permission только по явному reminder control; denied ведёт в Settings. Store commit не откатывается при ошибке системной очереди: UI отдельно показывает статус/retry и считает только реально возвращённые pending requests. Lifecycle/30s active refresh сверяет очередь, после relaunch читает persisted tasks. Нет сервера/APNs/background entitlement.
