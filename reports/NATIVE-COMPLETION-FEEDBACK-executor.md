# NATIVE-COMPLETION-FEEDBACK — 2026-10-18

REVIEW. Codex самостоятельно по прямому запросу, task/NATIVE-COMPLETION-FEEDBACK отca80c2d. Main/push не менялись.

## Реализация

IOSInboxModel.setCompleted запоминает newlyCompleted = requested true && prior false. После try store.setCompleted + reload вызывает OrbitCompletionFeedback.shared.completed только для этого перехода. catch/rollback path, reopen и repeated true не вызывают completion feedback. Любой список/Calendar/меню tiny tasks используют тот же central model method, без UI-дублирования.

Новый @MainActor feedback service: UINotificationFeedbackGenerator.success, только если прежний OrbitHaptics.enabled; AVAudioPlayer проигрывает original orbit-complete.wav (0.4s, восходящие C6/G6), только если новый UserDefaults orbit.ui.completionSound true (defaulttrue). Settings Отклик имеет Toggle «Звук выполнения», независимо от notification sound. Ambient category смешивается с чужим audio и учитывает Silent/lock по API Apple: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient . Существующий notification preview уже использует ту же ambient category. Игрок удерживается singleton, rewind при новом completion, .75volume; аудиоошибка только логируется, не выдаёт ложную ошибку сохранения уже записанной задачи.

Генератор scripts/generate-orbit-sounds.py дополнен complete, прежние3WAV после регенерации bit-identical (нет gitdiff). Новый PCM mono44.1kHz/16bit,17640samples,35324bytes,0.4s, peak5693/32767 (.174), clipping отсутствует. Resource присутствует в подписанном app bundle.

## Checks / ограничения

Signed generic iOS BUILD SUCCEEDED /private/tmp/orbit-completion-feedback.log; Simulator BUILD SUCCEEDED /private/tmp/orbit-completion-feedback-sim.log; diff --check PASS. Model @MainActor, вызов после store success, failure/reopen/no-op guard проверены чтением. Core/schema unchanged, core suites не повторялись. Никакие уведомления не назначаются для звука завершения, permission не требуется.

Own simulator1A3DE04B-CFDB-4DB4-BC3D-CB429529DF7A обновлён и запущен. Today emptyAX доступен, attempt click FAB через CUA вернул elementHasNoFrame; coordinate fallback ранее стабильно noWindowsAvailable, обходные injectors не использовались. Поэтому runtime UI completion/play()==true/Toggle/no-op/rollback сценарии в этой сессии НЕ продемонстрированы. Синтетическая fixture UI не менялась (click не доставлен). Акустическая громкость, тактильный рисунок, Silent/other audio/haptic-off на физическом устройстве требуют QA владельца — сборка/PCM не доказывают физическое звучание/вибрацию.

Установка update-in-place на iPhone запрошена, результат ниже после devicectl. Личные данные/store не считывались.

Device update-in-place SUCCESS: local.orbit.ios, sequence2532. Фактическое ощущение звука/вибрации на iPhone пока UNVERIFIED.
