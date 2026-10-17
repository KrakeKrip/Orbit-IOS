# Обратный перенос и даты с задачами — 2026-10-17

REVIEW. Прямой запрос владельца, самостоятельная реализация Codex в текущей task-ветке поверх7aa3974. Main/push не менялись.

## Реализация

Существующий hold/move timed блока теперь отслеживает global location пальца. CalendarDayScreen измеряет global frame области «Без времени»; даже пустая область имеет min44pt. При наведении — accent-подсветка и один tick на входе. На отпускании в области вызывается существующий atomic setPlannedInterval(nil,nil), plannedDate/UUID/project/deadline/reminder не затрагиваются. Перед write повторная проверка live date/time/duration против frozen snapshot. Возврат работает и для continuation сегмента: сохраняется исходная дата задачи. Resize handles не вызывают этот путь. Отмена recognizer/disappear снимает hover без записи. Короткий tap остаётся меню, interval move/snap не меняются.

Shared MarkedDatePicker использует системный UICalendarView с native single-date selection и небольшими accent-точками на plannedDate, если есть хотя бы одна задача (open или completed). Undated не отмечаются. CalendarDayScreen и UpcomingListScreen используют один компонент; в проектном browsing фильтр по folder UUID, в Предстоящем все задачи. Диапазон1900–2199, locale ru_RU/calendar Gregorian. Дата по-прежнему проходит через существующий select/owner binding. Decorations обновляются при изменении набора дней, без записи в store. Поповер закрывается после выбора.

## Проверки и границы

Device и Simulator BUILD SUCCEEDED: /private/tmp/orbit-reverse-dots.log и /private/tmp/orbit-reverse-dots-sim.log; diff --check PASS. Единственный warning AppIntents metadata extraction skipped (нет зависимости). Core/schema/store не менялись, full core suites не повторялись; существующий interval clear использован без нового persistence path.

Own simulator1A3DE04B-CFDB-4DB4-BC3D-CB429529DF7A обновлён в прежнем синтетическом контейнере и запущен. AX/screenshot текущего Today доступен. Координатный click по вкладке Предстоящее возвращает noWindowsAvailable: календарный поповер/точки и обратный drag в этой сессии GUI UNVERIFIED; не считать build доказательством touch QA. Реальный iPhone QA, cancellation/resize regression/AXL/VoiceOver/тёмный поповер ещё не подтверждены. Личные данные телефона не читались. Снимок существующего режима доступен только как setup evidence, не proof новых функций.

## R1 — чрезмерный размер поповера

Владелец прислал physical screenshot: точки есть, но UICalendarView растянут по высоте и обрезан по краям. MarkedDatePicker теперь задаёт finite320×360pt вместо min/ideal без верхней границы. UIViewRepresentable sizeThatFits уважает предложенные bounds; UIKit compression resistance по обеим осям понижен, чтобы intrinsic size не выходил за frame. Gregorian firstWeekday=2 (понедельник). Семантика выбора/точек/store не менялась. Targeted device BUILD SUCCEEDED (/private/tmp/orbit-calendar-popover-size.log), diff --check PASS. Повторный physical screenshot после правки ещё UNVERIFIED; AXL/landscape/малый экран также UNVERIFIED.

## R2 — последняя неделя всё ещё обрезалась

Владелец подтвердил уменьшение поповера R1, но physical screenshot показывает обрезанные26–31. Fixed UIView sizing оказался недостаточен. Вместо дальнейшего подбора высоты UICalendarView удалён: shared picker теперь SwiftUI month grid с intrinsic height24pt weekday +4/5/6×44pt rows +header/padding. Ширина308pt+24padding, selected circle34pt и маленькие task dots, Monday-first. Предыдущий месяц/следующий ограничены1900–2199. Header даёт отдельный выбор месяца/года нативными wheel Picker; «Показать месяц» меняет только просматриваемый месяц, выбор дня коммитит binding и закрывает поповер. Подписи месяцев ru_RU, задача/дата/stores не записываются при browsing. Accessibility дня содержит «есть задачи»/selected trait. UIKit intrinsic negotiation больше нет.

Финальный iPhone BUILD SUCCEEDED (/private/tmp/orbit-calendar-grid.log), diff --check PASS. Foundation-расчёт days извлечён из фактического UI source в /private/tmp/orbit-month-grid-check.swift, выполнен xcrun swift с собственным module cache:3600месяцев1900–2199, все даты ровно один раз, правильные weekday columns, полный размер28/35/42 ячейки PASS. Это проверка расчёта, не визуальный GUI proof. Первому запуску Swift не хватило доступа к default module cache; повтор с temp cache PASS. Touch/визуальный popover/AXL/landscape после R2 пока UNVERIFIED; system wheel взаимодействия также ожидают проверки. Установка — update in place, личные stores не читались.
