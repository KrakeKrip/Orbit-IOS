# Calendar task scroll — 21 октября 2026

База c463c04; ветка task/CALENDAR-TASK-SCROLL. Пользователь сообщил: вертикальный свайп, начатый на календарной задаче, не прокручивает сетку.

## Исправление

SwiftUI LongPress.sequenced(before: Drag(minimumDistance:0)) и немедленный direct drag с выделенной карточки удалены из тела блоков Day/3days. Общий TimelineTaskHold использует существующий native TimelineScrollResolver: UILongPress0.45s/allowableMovement10 на конкретном enclosing UIScrollView с фильтром frame карточки. Пан прокрутки не ждёт нулевого drag; быстрое движение отказывает удержанию до входа в edit. Удержание входит в существующие move/candidate/commit пути, отмена очищает только свой черновик. Для повторного переноса тела тоже требуется hold; resize точки сохраняют прежний прямой drag и исключаются из области native hold. Позиция/translation native pointer использует те же global координаты и компенсацию scroll offset, включая3days.

Core/schema/storage и список не менялись. Нет пуша или установки на телефон.

## Фактические проверки

- Финальный Simulator BUILD SUCCEEDED; git diff --check PASS. Core124 не повторялись: только UI.
- CUA, собственный orbit-untimed-codex1A3DE04B-CFDB-4DB4-BC3D-CB429529DF7A, synthetic Month check21Oct09:00–09:30.
- Day: свайп от тела(1075,580) вниз→видимая сетка08:00 сменилась на00:00, задача09:00 сохраняет интервал, меню/редактирование не открылись.
- Hold650ms на теле→появились точки/выделение без изменения09:00–09:30. Затем быстрый свайп с выделенного тела снова прокрутил сетку к00:00.
- 3days: свайп от задачи(910,710) вверх→шкала08:00 сменилась на17:00, без меню или ghost. CUA иногда noWindowsAvailable, восстановлено Raise; неподвижный первый trial не считался успешным.

Непроверено: единый непрерывный hold→move→release (CUA click(duration) отпускает до отдельного drag), физический iPhone/haptics, полные resize/autoscroll/overnight/return-untimed regressions и accessibility. Эти paths сохранены, но код не равен физическому тесту. Личные stores/телефон не использовались.
