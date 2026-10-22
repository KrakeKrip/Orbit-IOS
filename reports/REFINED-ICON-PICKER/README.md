# refined-01 — выбор иконки

22 октября 2026. Настройки → Иконка приложения. Три фона × четыре акцента, локальный предпросмотр, явное применение. Тема приложения независима. Фактическая иконка читается из UIApplication.alternateIconName; основной вариант возвращается через nil. Проверяется supportsAlternateIcons, повторный запрос блокируется. Ошибка сохраняет draft, успех подтверждается фактическим alternateIconName.

Ресурсы: 12 стандартных исходных PNG без изменений, 12 dark (соответствующий night), 12 монохромных tinted на чёрном; 12 previews. Xcode регистрирует 11 альтернатив для Debug/Release. Исходный refined-01 пакет сохранён в docs/brand/refined-01, включая SVG, wordmark и HTML. scripts/prepare_app_icons.py воспроизводит каталог из ZIP (Pillow).

Проверки: Simulator и подписанная device сборка BUILD SUCCEEDED; проверены все 36 RGB PNG 1024×1024 и точное соответствие 11 имён compiled Info.plist. Собственный iPhone17 Simulator/iOS27: начальное состояние/disabled Apply, смена draft без изменения installed, выход без применения и возврат, фактическая системная смена на Night Blue, повторное открытие с этим состоянием, возврат к основной через nil. Системный alert показал реальные иконки (dark appearance), после завершения installed соответствует выбору. Темы/задачи не менялись.

Подписанная сборка установлена на физический iPhone поверх существующего приложения; devicectl подтвердил установку и запуск. Физический выбор вариантов пользователем, все 12 системных смен, Clear/tint на домашнем экране, VoiceOver, AX5 и iOS17 ещё не проверены. Ошибка API и unsupported обработаны кодом, принудительно в GUI не воспроизводились. Данные/OrbitCore не менялись; core tests не перезапускались. Push не выполнялся.

API: https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons
