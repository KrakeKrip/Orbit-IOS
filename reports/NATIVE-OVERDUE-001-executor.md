# NATIVE-OVERDUE-001

Base 6f5be3a, task/NATIVE-OVERDUE-001, отдельный worktree.

## Итог
Общий сворачиваемый блок «Просрочено · N» добавлен в Today List, Inbox, Upcoming List/Agenda, CalendarDayScreen (Today/Upcoming/project) и список проекта. В проекте фильтр только по его UUID; индекс папок не показывает глобальные задачи. Задачи: open, valid plannedDate < local today; отдельный deadline не подменяет плановую дату. Во Inbox/project List они исключены из обычного раздела открытых, completed/undated в блок не попадают. В выбранном историческом календаре/повестке контекстный день по-прежнему показывает свои задачи.

Блок по умолчанию свёрнут, развёрнутые строки имеют ограниченную измеряемую высоту и свои обычные editor/completion callbacks. Перенос одной/всех задач блока на сегодня/дату, выбор задач через меню. В общей нижней панели выбора добавлена кнопка переноса выбранных на сегодня/дату. Ошибка не закрывает draft/выбор; Cancel не пишет. Форма явно объясняет сохранение интервала, независимого дедлайна и абсолютного напоминания.

Store rescheduleTasks валидирует дату, каждый UUID и каждый derived end до мутаций, дедуплицирует, no-op без save, один save/rollback. Только plannedDate меняется, схема неизменна. Reload обновляет shared model и reminders service.

## Проверки
- Полный swift test: 119/119 PASS (3 новых теста: overdue predicate, atomic invalid/unknown/overflow refusal+retry, metadata+overnight+disk reopen). Лог /private/tmp/orbit-overdue-tests.log. Expected failed-open fixture печатает CoreData errors, сам тест PASS.
- Final Simulator и signed iOS builds: BUILD SUCCEEDED, /private/tmp/orbit-overdue-sim-final.log, /private/tmp/orbit-overdue-device-final.log. git diff --check PASS.
- CUA GUI, только свой orbit-untimed-codex: Today block1, expand с «На сетку»/красной датой; Inbox block1 без дублирования этой задачи в обычном списке; Upcoming Agenda/Calendar block1, календарная сетка/контролы видимы.
- Форма выбранной даты: native wheel, явные Cancel/Перенести; Cancel возвращает без записи. При первой проверке inherited hidden navigation bar прятал toolbar-кнопки: заменены явным HStack внутри формы по существующему редакторному паттерну; финальные кнопки реально проверены.
- Inbox bulk select A+B (2 completed synthetic tasks) → перенос → native wheel tap19окт → Save: режим выбора закрыт; SQLite подтверждает обе даты19окт, прежние UUID и одинаковые прежние completedAt сохранены, третья задача не изменена. Отличаются только ZPLANNEDDATE и служебный Z_OPT двух строк.
- Быстрый перенос всех просроченных (одна «На сетку») на today18окт: block исчез, задача появилась в Открытых. SQLite подтверждает только дату17→18 у этого UUID; completedAt=nil. Terminate/relaunch: На сетку в Today, overdue block отсутствует; A/B остаются на19окт.
- iPhone install успешен, sequence2628, поверх текущей версии. Личные данные устройства не читались и не удалялись.

Evidence: /Users/atlhnv/Codex/orbit-outputs/NATIVE-OVERDUE-001/ — before.sqlite, after-batch.sqlite, after-today.sqlite; только синтетические store, в Git не включены.

## Не проверено отдельно
UI project-only isolation (в собственном fixture не было проектов), Today Calendar/Upcoming List (те же shared components собраны), тёмная тема, AXL/VoiceOver/реальная полночь, реальная отправка напоминания после переноса, runtime save-failure injection. Project filtering и периодическое обновление даты присутствуют в коде; это не physical QA. Core metadata/no-partial-save покрыты tests, реальная авария диска не моделировалась. Main/push не менялись.
