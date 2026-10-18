# OrbitCore

Swift-пакет — непосредственная зависимость [iOS-приложения](../OrbitIOS/README.md). Содержит SwiftData-модели, хранилище, правила civil-дат/интервалов, проекты, дедлайны, напоминания, массовые операции и чистые расчёты календарных жестов.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd apple/Orbit
swift test
```

Swift tools6.0, iOS17+. macOS14 указан для запуска тестов ядра на Mac; executable macOS-приложения в пакете нет. Core не зависит от UIKit/AppKit, HTTP или CloudKit. iOS-путь хранилища задаёт IOSStore внутри sandbox, а не CLI-аргументы.

Название задачи: trim,1…500 Unicode scalars. Planned date: Gregorian YYYY-MM-DD,1900–2199. Time+duration — полная пара при наличии даты; новые интервалы5…1440мин, старые1…4читаются без переписывания. Derived end вычисляется. Валидация до мутации, save/rollback, сохранение UUID. Подробности — [архитектура](../../ARCHITECTURE.md).
