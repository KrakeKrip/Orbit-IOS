# NATIVE-SOUND-001 — общий звук уведомлений

DONE по Codex self-check,2026-10-17. Ветка task/NATIVE-SOUND-001 от d621656. Отдельного независимого исполнителя/review нет.

## Результат

Настройки → Уведомления → Звук: Стандартный, Без звука, Колокольчик, Капля, Сигнал. Только один device-local выбор (UserDefaults orbit.reminder.sound), никакого поля звука на задаче/изменения SwiftData schema. Неизвестное/отсутствующее preference → standard. Preview отдельной кнопкой не меняет выбор. Bundled preview AVAudioPlayer/ambient; standard preview через public UN API с foreground .sound без banner/list. Для standard требуется разрешение; ошибки явные. При уходе/смене/фоновой фазе preview останавливается; уникальный ID и revision guards не дают старому callback отменить новый preview.

ReminderRequest получил sound с default.standard; planner и serial worker получают snapshot общего выбора. Сравнение full request вызывает replacement того же stable ID, не меняя title/fireAt; старая pending metadata без sound считается standard. Переключение preference не пишет задачи. Silent → content.sound=nil; custom → UNNotificationSound(named:), standard → .default. Ошибка очереди остаётся видимой через существующий status/retry.

Три оригинальных WAV (44.1kHz mono16-bit PCM,0.86–1.21s) созданы scripts/generate-orbit-sounds.py, без чужих аудио/системных private paths или sound IDs. Все3 реально включены в .app. Apple формат/ограничение: https://developer.apple.com/documentation/usernotifications/unnotificationsound .

## Проверки

- swift test:112/112 PASS (13 suites), включая3 actual previous-source migration fixtures. Два новых теста: глобальная смена standard/custom/silent для существующего запроса без изменения task identity/title/time, idempotence/restart; смена во время in-flight add оставляет последний sound.
- iOS Simulator build PASS, финальная сборка после защиты preview callback. Единственный warning AppIntents metadata skipped (нет AppIntents dependency). Первый sandboxed swift test не стартовал из-за compiler cache permissions; штатный elevated запуск PASS.
- Own iPhone17/iOS27 Simulator26507827-A434-4410-AB5D-AD1E668F76BD: меню5пунктов, выбор chime, три bundled preview без UI-ошибки, preview не меняет выбранный chime; relaunch/update сохранил chime; silent отражён в summary/checkmark; final UserDefaults drop подтверждён read-only.
- Первый standard preview после initial Allow вернул известный Source-is-not-authorized в свежем Simulator. После reboot своего Simulator final build успешно вызвал настоящий standard preview: system log shouldPresentAlert:NO/hasSound:1/shouldPlaySound:1, willPresent response2; лишнего баннера/NC-записи нет. Исходная причина регистрации не установлена, продукт не скрывает ошибку и не перезагружает устройство.
- Через GUI создана синтетическая задача «Проверка общего звука» и reminder17окт17:40MSK при global silent (actual pending1). ДО доставки выбран drop, процесс завершён17:39:41. В17:40 Notification Center показал Orbit/название задачи. SpringBoard ToneLibrary использовал именно bundled orbit-drop.wav, create returned0, hasPlaybackStarted:YES, playedToEnd, didFailToPrepareSound:NO. Это real-system replacement/delivery при закрытом процессе, не только fake-client тест.

Evidence: /Users/atlhnv/Codex/orbit-outputs/NATIVE-SOUND-001/ —01-sound-options.png,02-delivered-after-sound-change.png,preview-system.log,reschedule-delivery.log,core-112.log,ios-build.log,audio-assets.json.

UNVERIFIED: акустическое восприятие/громкость на физическом iPhone, беззвучный переключатель/Focus/Bluetooth, VoiceOver, AXL/тёмная тема в этом проходе; runtime persistent-write/disk faults не инъецировались. Silent verified mapping/code+core replacement, отдельной real-system silent delivery не было. Реальные task stores не читались. Personal iPhone не обновлялся, push не выполнялся.
