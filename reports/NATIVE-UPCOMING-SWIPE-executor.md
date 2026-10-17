# NATIVE-UPCOMING-SWIPE

Base: 48a8407; task/NATIVE-UPCOMING-SWIPE, отдельный worktree.

## Изменение
Список «Предстоящее» владеет горизонтальным жестом только в области контента, включая пустое состояние. Влево — ровно один civil day вперёд, вправо — назад. Threshold 70 pt, горизонтальная компонента > вертикальной ×1.6, без predicted momentum. При выборе задач и открытом date/time editor жест ничего не меняет. Дни проходят существующий shiftedDay/validator 1900–2199. Один selectedDay owner остаётся в workspace, общий свайп workspace исключает List во избежание двойного перелистывания. Прежние Calendar/Agenda жесты сохранены (добавлен guard bulk selection).

Контент меняется переходом slide+opacity 0.22s с направлением; Reduce Motion использует opacity 0.12s. Заголовок/дата остаются на месте; DatePicker получил AX value текущей даты. Tasks/store/schema не менялись.

## Проверено
- Final iOS Simulator и signed generic iOS: BUILD SUCCEEDED. Логи /private/tmp/orbit-upcoming-swipe-sim-final.log и orbit-upcoming-swipe-device-final.log.
- Настоящие CUA drag на своём orbit-untimed-codex: populated 18→empty19→18→populated17, дата AX и набор задач меняются согласованно; повторный свайп через empty20 и обратно также выполнен в первом проходе.
- Вертикальный drag с небольшим боковым смещением не меняет дату (короткий список без overflow).
- При выборе одной задачи горизонтальный drag не меняет дату, выбор/счётчик сохраняются.
- Read-only dump собственного синтетического store до/после финального прохода идентичен.
- git diff --check PASS. Unit/core/web не повторялись: core/store не менялись; новые тесты для UI жеста не добавлялись.

Evidence: /Users/atlhnv/Codex/orbit-outputs/NATIVE-UPCOMING-SWIPE/ (before.sql/after.sql, 01-previous-day.png). Только синтетические данные; в Git не включены.

## Границы проверки
GUI 1900/2199, реальный длинный scroll, Reduce Motion, VoiceOver, AXL и physical touch не показаны. Защита диапазона использует прежний существующий validator. Длинный CUA drag, начатый на самой строке, открыл её существующее hold-menu (0.45s); такой синтетический сценарий не считается подтверждением быстрого swipe со строки. Основной swipe проверен в свободной области списка. Пользовательские данные не читались/не удалялись. Main/push не менялись.
