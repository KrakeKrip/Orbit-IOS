# Разделение Orbit iOS / Web / macOS

18 октября2026, исходный снимок72417009de790211047e7e667f9e112ea25031fe.

## Перенос

200 tracked web-файлов скопированы в отдельный Orbit-Web и проверены SHA-256 до удаления из iOS tree: src/tests/drizzle, web scripts/configs, package/lock/env example, web source/baseline docs и TASK-отчёты. Документы корня Web заменены web-спецификацией, README и команды относятся к новому репозиторию. Никаких .env, stores, node_modules или персональных файлов в переносе.

macOS-прототип сохранён отдельно локально в /Users/atlhnv/Codex/Orbit-MacOs-staging: полный исходный Swift-пакет45файлов с ядром/tests и NATIVE-001-документами. Remote ещё не существует, macOS не опубликован. Из iOS удалены executable OrbitMac, его source, CLI store resolver и5его тестов. Остальной OrbitCore нужен iOS и сохранён. macOS14 в platforms остаётся для swift test на Mac.

iOS-корневые документы переписаны под актуальную платформу; старые mixed документы доступны в исходном Git-коммите, история не переписывалась. Нативные отчёты оставлены как история проверок iOS/ядра, старые упоминания macOS/Web в них не являются текущими инструкциями.

## Проверки

- Swift core124tests/16suites PASS;5macOS-only CLI tests вынесены, не потеряны.
- iOS Simulator BUILD SUCCEEDED из очищенного iOS-worktree, без Web/macOS executable.
- Web npm ci offline PASS; lint/typecheck/69unit PASS. Production webpack build PASS; default Turbopack blocked by environment local-port restriction; DB/auth/E2E и production не запускаются в этом переносе.
- Manifest переноса с SHA-256 сохранён вне репозиториев: orbit-outputs/IOS-REPO-SPLIT/manifest.json.

Личные базы, iPhone, действующие БД/контейнеры и ignored caches не изменялись. Новый Simulator с синтетическими задачами используется только для README screenshots.
