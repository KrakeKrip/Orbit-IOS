# NATIVE-REMINDER-001 — итог 2026-10-17

Статус: DONE по Codex self-check на Simulator. Отдельного независимого исполнителя/review не было. Этот раздел заменяет прежний открытый runtime gate ниже. Физический iPhone и звук не проверены, push/install не выполнялись.

## Продолжение после обновления лимита

Код 69daf08 не менялся. После обычного boot собственного Simulator 24D3853C-4344-4DEC-9197-EA46F69D9184 контрольный ReminderProbe успешно поставил запрос (Queued:1), и его уведомление появилось в Notification Center. Orbit также успешно добавил настоящий UTC calendar trigger: Settings показывал фактический pending count1. Прежняя Source-is-not-authorized ошибка не повторилась. Точная причина исходного отказа не установлена; это не доказательство устранения всех платформенных проблем и не основание для автоматического reboot в продукте.

GUI через CUA: создана задача «Доставка после перезапуска»; reminder05:07 сохранился, pending1. Complete в05:06:14 отменил pending (UI0 и системный log remove). Reopen произошёл в05:07:01, уже после времени: корректно не восстановил просроченный reminder. Первоначальная commentary-фраза о восстановлении была преждевременной; восстановление будущего значения покрыто core fake-backend тестом, но в этом GUI-сценарии не подтверждено.

Через настоящий редактор назначено новое время17окт2026 05:12 MSK, UI pending1. Процесс Orbit принудительно завершён simctl terminate ДО времени доставки. В05:12 центр уведомлений показал ORBIT / Orbit / «Доставка после перезапуска» (AX и screenshot). Это подтверждает реальную системную доставку при отсутствующем процессе, без QA overrides и без подмены store/системных часов.

Evidence: 02-queued-after-reboot.png,03-completed-cancels.png,04-delivered-process-terminated.png; reboot-runtime.log; прежние core-110.log и ios-lifecycle.log. Папка /Users/atlhnv/Codex/orbit-outputs/NATIVE-REMINDER-001/. Продуктовый код после последней успешной сборки/110 tests не менялся, поэтому suite/build без новой причины не повторялись. Source review: ownership, atomic store writes, callback wiring, стабильные ID, stale worker guards, UTC trigger, permission UX проверены чтением diff.

Остаются UNVERIFIED: реальный iPhone/звук/VoiceOver; foreground banner отдельным сценарием; физическая смена timezone/DST; runtime disk-save fault injection; >64 real-system queue. Эти границы не подменены core-тестами. Основные контракты и ограничение queue documented в README/ARCHITECTURE/ADR052.

---

## История остановки 2026-10-17

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
