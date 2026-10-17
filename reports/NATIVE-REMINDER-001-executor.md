# NATIVE-REMINDER-001 — сохранённый результат

Статус: NEEDS_FIXES. Работа остановлена по просьбе пользователя из-за остатка лимита. Ветка task/NATIVE-REMINDER-001, база 7971d3f. В main не интегрировано; push и установка на личный iPhone не выполнялись.

## Реализовано

Опциональное reminderAt — абсолютный момент, независимый от planned date/interval и deadline. Atomic create/edit/clear, валидация до записи, сохранение старой схемы. Shared create/editor/menu/badges и permission UX. Запрос разрешения только по явному действию пользователя. Serial reconciliation по value snapshots: стабильный ID, отмена при complete/delete/clear, reopen только будущего напоминания, обновление title/time, защита от stale async add. Консервативная очередь 64 с учётом чужих pending; чужие записи не удаляются. Foreground banner/list/sound delegate. Ошибки и deferred queue показываются явно.

## Проверки

- Core: 110/110 PASS, включая actual previous-source disk upgrade, store validation/persistence, planner и fake-backend async races/retry/cancellation. Это не доказательство системной доставки.
- iOS Simulator build: BUILD SUCCEEDED, последний лог ios-lifecycle.log.
- Own Simulator GUI: настройка/сохранение напоминания, denied state, явное разрешение через Settings, persistence. Два собственных iOS27 Simulator, включая чистый initial Allow.
- Реальная доставка: НЕ ПРОШЛА. notificationSettings сообщает authorized, но add возвращает «Repository could not save notification. Source is not authorized.»; SpringBoard пишет «Dropping records because local client does not exist». Повтор с ad-hoc signed package и deferred scheduler start не устранил ошибку. Причина не установлена; нельзя утверждать, что это только дефект Simulator.
- Отдельный temp ReminderProbe собран/запущен для контроля публичного API, разрешение выдано; результат add не проверен до остановки. Не использовать его как доказательство причины.

## Что осталось

Установить причину системного отказа и подтвердить реальную доставку, отмену и повторное планирование через UserNotifications. Проверка на физическом устройстве, VoiceOver, реальная доставка в background/terminated и системные ограничения Focus не подтверждены. Независимого review не было. До закрытия runtime gate не считать этап DONE и не интегрировать как принятую функцию.

Evidence: /Users/atlhnv/Codex/orbit-outputs/NATIVE-REMINDER-001/. Синтетические stores; личные данные не использовались.
