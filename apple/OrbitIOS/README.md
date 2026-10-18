# Orbit для iPhone

Актуальная native-версия Orbit: «Сегодня», «Входящие», «Предстоящее» и «Проекты», список и календарь, создание и редактирование задач, перенос и изменение интервала жестами, темы оформления. Общий обзор возможностей и ограничений — в [корневом README](../../README.md).

## Требования и сборка

- Deployment target: iOS 17+, только iPhone. Отдельный GUI-прогон на iOS 17 не заявляется.
- Текущая проверенная среда: Xcode 27 и iOS 27 Simulator.
- Схема `OrbitIOS`, bundle identifier `local.orbit.ios`.
- Локальный Swift package `../Orbit`, product `OrbitCore`. Сервер, Node.js и `.env` не нужны.

Из корня репозитория:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
open apple/OrbitIOS/OrbitIOS.xcodeproj

xcodebuild \
  -project apple/OrbitIOS/OrbitIOS.xcodeproj \
  -scheme OrbitIOS -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/orbit-ios-build \
  CODE_SIGNING_ALLOWED=NO build
```

Запуск — через Run в Xcode на выбранном Simulator. Для физического iPhone настройте свою Development Team и provisioning; unsigned Simulator build не является установочным пакетом для телефона. Не коммитьте персональные настройки подписи и сертификаты.

## Где находится код

| Файл | Назначение |
| --- | --- |
| `OrbitIOS/OrbitIOSApp.swift` | Открытие единственного локального store и app entry. |
| `OrbitIOS/IOSStore.swift` | Путь базы в sandbox и явная ошибка открытия без пустого fallback. |
| `OrbitIOS/IOSInboxModel.swift` | Общая модель UI и операции через OrbitCore. |
| `OrbitIOS/TodayWorkspaceScreen.swift` | Текущий локальный день и вид «Сегодня». |
| `OrbitIOS/UpcomingWorkspaceScreen.swift` | Выбранный день и независимый вид «Предстоящего». |
| `OrbitIOS/CalendarDayScreen.swift` | Дата, область задач без времени и календарь дня. |
| `OrbitIOS/DayTimelineView.swift` | Шкала, overlap-колонки, выделение, перенос и resize. |
| `OrbitIOS/ProjectsScreen.swift` | Индекс проектов, create/rename и нижний FAB создания проекта. |
| `OrbitIOS/TaskActionPopover.swift` | Общая карточка и меню действий по задаче. |
| `OrbitIOS/TaskCreatePresentation.swift` | Общая кнопка «+» и форма создания с локальным черновиком. |
| `OrbitIOS/TaskDateSheet.swift`, `TaskIntervalSheet.swift` | Редакторы даты и времени существующей задачи. |
| `OrbitIOS/NativeModeHeader.swift`, `OrbitInterface.swift` | Общая шапка, темы, системные кнопки, настройки и haptics. |

## Правила UI

- День/вид принадлежат workspace; переключение не создаёт копии задач. Выбор вида сохраняется между запусками отдельно по workspace и проекту.
- «Сегодня» всегда относится к текущему локальному дню. «Предстоящее» сохраняет вручную выбранный день; его список показывает выбранный день, листается свайпами; отдельная «Повестка» показывает последовательность дней и синхронизирует недельную шапку с прокруткой.
- FAB создаёт задачу с preset: Inbox — без даты, Today — сегодня, Upcoming — выбранный день. Форма позволяет изменить preset до сохранения.
- Начало в колёсиках выбирается с точностью до минуты, длительность — с шагом 5 минут, диапазон 5…1440 минут.
- Короткий тап по календарному блоку открывает popover. Удержание включает перенос; тело перемещается с шагом 5 минут, точки меняют интервал с привязкой длительности к 10 минутам и минимумом 5.
- Пустая сетка: неподвижное удержание 0,45 с создаёт черновик на 30 минут, протягивание меняет длительность с шагом 10 минут и минимумом 5, начало привязывается к 5 минутам; отпускание открывает общую форму, запись только после подтверждения.
- Край viewport запускает автопрокрутку move/resize/create; компенсация использует global translation плюс actual UIScrollView offset delta.
- Жест переноса/размера редактирует черновик; запись выполняется на отпускании. Тап в свободное место снимает выделение.
- Дата, время, rename и delete используют существующий shared store; ошибки не выдаются за успешную запись.

Проекты используют тот же `IOSInboxModel`/store. Tap открывает `ProjectWorkspaceScreen` со списком/календарём; rename доступен в context menu индекса. Нижний плюс создаёт проект в индексе и задачу внутри папки. Проект выбирается при создании или через меню существующей задачи. [Проверки папок](../../reports/NATIVE-PRJ-003-004-executor.md).

## Хранение и проверки

Store: `<app container>/Library/Application Support/Orbit/store.sqlite`. Приложение не принимает iOS launch-override для чужих баз. Обновление поверх установленного приложения сохраняет его контейнер; удаление приложения не является способом обновления.

Core-тесты запускаются отдельно из `apple/Orbit`: `swift test` с выбранным `DEVELOPER_DIR`. GUI и анимации проверяются на отдельном Simulator с синтетическими задачами. Запуск на личном iPhone подтверждён владельцем; это не полный physical smoke всех функций. Последний полный core-прогон: 124 теста / 16 suites PASS после разделения платформ. Последние исправления и ограничения: [автопрокрутка](../../reports/NATIVE-CALENDAR-AUTOSCROLL-executor.md), [компактная форма и быстрые жесты](../../reports/NATIVE-CREATE-COMPACT-executor.md).

Форма создания использует фиксированную верхнюю строку Cancel/Add, один large detent и компактные секции; deadline/reminder раскрываются через «Дополнительно». В action popover отключён блокирующий modal transition и отложенное открытие. Общая модель/атомарные store-операции не менялись в этих UI-исправлениях.
