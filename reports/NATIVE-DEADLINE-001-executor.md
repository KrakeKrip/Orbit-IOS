# NATIVE-DEADLINE-001 — независимый дедлайн

2026-10-16. Codex implementation/self-check. База5ab4c55, ветка task/NATIVE-DEADLINE-001. Пользователь одобрил дедлайн следующим этапом; reminders/notifications отдельно.

## Реализация

OrbitTask.deadlineDate optional String? Gregorian civil YYYY-MM-DD1900–2199. Existing init/create callers default nil, старые строки получают nil при additive upgrade. Internal setter, validated store.setDeadlineDate (identical no-op) и atomic addTask whole candidate: invalid deadline до insert/мутации, ровно один save с rollback/rethrow. Deadline может быть раньше/позже plannedDate или существовать без расписания/проекта. Остальные поля/UUID/order/membership/projector/gesture rules не меняются.

Срок до конца дня: open && valid deadline < valid local today. Сегодня ещё не overdue, completed сохраняет срок без overdue, reopen возвращает статус. Чистый helper TaskDeadline без timezone instants. Badge TimelineView обновляет отображение раз в минуту без store write; реальная смена полуночи в GUI не имитировалась.

Общая create form: optional local draft, expandable native civil date wheel, явное подтверждение без вращения, clear. Открытие группы не назначает срок. В существующей задаче общий popover → Дедлайн… → стабильный sheet-host после dismiss; Save/Cancel и local draft. Tiny timed menu тоже открывает редактор. В shared list видна дата/Просрочено, compact untimed/timed — флажок и полный срок в popover/AX. Точная высота временного блока сохранена; tiny сегмент не растягивается ради текста.

При AXL найдено обрезанное длинное меню. Исправлено в этом scope: bounded scroll popover, scaled ideal height с пределом520pt, labels растут вертикально. Жест CUA реально прокрутил до Проект/Дедлайн/Переименовать/Удалить, screenshot04. Строка дедлайна адаптируется в два ряда при нехватке ширины, короткий navigation title «Дедлайн».

## Проверки

- Полный swift test: **104/104**,12 suites PASS, exit0. Оба env-fixture включены, не skipped.
- 3 новых теста: строгие даты/границы/leap/same-day-next-day/completed/invalid today; atomic create refusals/no extra row/retry/unknown/nil/change/clear/reopen/unchanged neighbors+all scheduling/project fields; actual previous-source upgrade.
- Previous source взят git show5ab4c55 в temp package, отдельный старый бинарник создал project + timed completed task с projectID; UUID oracle JSON и timestamps. Новый код открывает копию с sidecars, сохраняет UUID/title/createdAt/completedAt/project/scheduling, deadline nil; новый срок сохраняется/reopens. Дополнительно прежний PRJ003 upgrade oracle тоже PASS. Личные базы не использованы.
- iOS Simulator build PASS; после косметических/AXL исправлений targeted rebuild PASS, финальный лог ios-final2.log. Core после полного104 не менялся.
- Живой CUA GUI на своём iPhone17/iOS27 Simulator orbit-deadline-codex,9A87AC6E-553A-4D17-A796-AC4E13F94F34. Кириллица через AX setValue. Created «Задача со сроком»: planned2026-10-16, deadline2026-10-15, без времени; store ровно1row. В Today красное «Просрочено ·15окт».
- Existing menu editor: clear draft→Cancel, persisted deadline прежний. Complete→нет overdue; reopen→overdue возвращён. Read-only snapshot семантически равен initial (кроме revision после completion pair).
- Clear→Save действительно NULL deadline, plannedDate/title/UUID прежние. Calendar untimed menu→confirm already shown16окт без вращения→Save: due today, не overdue, флажок. Затем существующий interval editor Save09:00/30: тот же UUID/deadline сохраняется, timed block с флажком виден.
- In-place Simulator install/relaunch: тот же deadline/task/interval. Финальный dark/AXL smoke: list wraps deadline, menu scrolling и editor; исходный frame/grid clipping на AXL не переделывался.
- Финальный read-only sqlite: ровно1row, прежние UUID/title/createdAt/plannedDate, deadline16окт/09:00/30, completed nil; final.json. Тестовый контейнер, git diff --check PASS.

## Ограничения

Physical iPhone, VoiceOver, small-width/landscape, real midnight/timezone transition GUI, runtime save-failure fault injection — UNVERIFIED. Core covers boundary logic; build/source не выдаются за эти проверки. GUI deadline-only undated create, future-date and tiny-menu deadline path отдельно не прогонялись (store tests/shared source). Notifications и permissions не добавлены. Пользовательская установка/публикация этого этапа не выполнялись автоматически.

Evidence: /Users/atlhnv/Codex/orbit-outputs/NATIVE-DEADLINE-001/. Промежуточные screenshots01–03 предшествуют финальному scroll/adaptive-summary исправлению; screenshot04 подтверждает menu scroll. Итоговый editor screenshot05 относится к финальному коду. Собственный simulator очищается после завершения, чужие устройства не трогаются.
