# NATIVE-AGENDA-001 — Повестка и иконка (2026-10-17)

REVIEW, самостоятельная работа Codex по прямым запросам. Ветка task/NATIVE-AGENDA-001 поверх14e08dc, main не менялся/push не выполнялся.

## Что добавлено

Upcoming имеет третий пункт «Повестка», icon calendar.badge.clock, через additive agenda binding в общем mode menu. Today/projects сохраняют два пункта. Новый AppStorage orbit.ui.upcoming.agenda; старый calendar key сохранён, при выборе menu записывается согласованная пара, mode survives relaunch по wiring. Reference/current selected civil day по-прежнему принадлежат UpcomingWorkspace; одна aggregate haptic на смену mode.

UpcomingAgendaScreen: общая top row/settings, дата с принятым marked month picker, понедельник-воскресенье с точками plannedDate, week arrows и контекстная Today. Тап дня скроллит к его секции; если день вне loaded range — новый range. Начальные56последовательных civil дней, затем +28 при появлении последней секции; upper2199 clipped. Пустые дни показаны; rows — InboxRowView с shared actions/UUID, дата в rows скрыта, header включает сегодня/завтра/weekday. Inline+ создаёт TaskCreateSheet с preset соответствующего дня (изменяемый draft), global FAB сохранён с выбранным днём. Cancel/editor/store semantics существующие. Отдельного overdue блока/переноса overdue не добавлялось, вертикальный scroll не переписывает выбранный день автоматически. Theme canvas применяется и к пустым rows.

Иконка — встроенный imagegen, opaque1254×1254original сохранён design/orbit-icon/orbit-icon-original.png, exactprompt/описание design/orbit-icon/README.md. Для asset catalog стандартный sips downsample1024×1024 без творческих изменений; RGB/noalpha проверено. Assets.xcassets/AppIcon.appiconset/OrbitIcon.png, Xcode APPICON_NAME=AppIcon в Debug/Release project config. Device build Info.plist содержит CFBundleIcons/CFBundlePrimaryIcon/CFBundleIconName=AppIcon; нет ручной смены подписей/профиля. Команда использует прежний CLI team override.

## Проверки

Generic signed iOS и Simulator BUILD SUCCEEDED: /private/tmp/orbit-agenda-icon.log, /private/tmp/orbit-agenda-icon-sim.log; после объединения haptic выполнен финальный generic build /private/tmp/orbit-agenda-icon-final.log. AppIntents metadata skipped — единственный compiler warning. Initial physical-id build не нашёл unavailable phone, поэтому перешёл на generic device build (не устройство). Asset1024×1024, alpha=no, generated CFBundleIcons проверены. Diff --check PASS.

Фактические shift/days/week helpers из UpcomingAgendaScreen собраны с production TaskPlannedDate source в собственный temp Swift checker:18boundary/leap/DST/timezone scenarios PASS (1900-01-01,2024-02-28,2026-03-08,2026-10-17,2199-12-30/31; Europe/Moscow,America/New_York,Pacific/Kiritimati). Unique/same range/Monday columns/selection presence/out-of-range rejected. Это проверка civil расчёта, не GUI. Core unchanged, full112 suites не повторялись.

Own simulator1A3DE04B-CFDB-4DB4-BC3D-CB429529DF7A обновлён/запущен с синтетической старой fixture; Today AX/screenshot доступны. Coordinate click по Upcoming снова noWindowsAvailable, Tab Bar children не доступны в AX. Поэтому выбор Agenda/menu/week/inline create/pagination/relaunch/AXL/VoiceOver/иконка на Home — GUI UNVERIFIED. Обходные UI injectors не использовались. Предыдущие UI задачи также остаются pending physical QA отдельно.

iPhoneAtl (00008140-000E70281E0A801C) unavailable в devicectl, новая версия на личный iPhone НЕ установлена. Личные данные не читались; тестовая fixture не изменялась операциями UI.
