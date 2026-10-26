import SwiftUI
import UniformTypeIdentifiers
import OrbitCore

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct OrbitBackupScreen: View {
    @Environment(IOSInboxModel.self) private var model
    @State private var export: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var candidate: OrbitBackup?
    @State private var plan: OrbitBackup.Plan?
    @State private var message: String?
    @State private var error: String?
    @State private var confirming = false

    var body: some View {
        Form {
            Section {
                Button("Сохранить копию в файл", systemImage: "square.and.arrow.up") {
                    do { export = BackupDocument(data: try model.exportBackup()); exporting = true; error = nil }
                    catch { self.error = error.localizedDescription }
                }
                Button("Выбрать файл для восстановления", systemImage: "square.and.arrow.down") {
                    candidate = nil; plan = nil; message = nil; error = nil; importing = true
                }
            } footer: {
                Text("Копия содержит задачи, проекты, архив, теги, даты и напоминания. Оформление, иконка и разрешения устройства не включены. Файл не зашифрован — храните его в надёжном месте.")
            }
            if let candidate, let plan {
                Section("Предпросмотр") {
                    LabeledContent("Создана", value: candidate.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Добавится тегов", value: "\(plan.newTags)")
                    LabeledContent("Добавится проектов", value: "\(plan.newProjects)")
                    LabeledContent("Добавится задач", value: "\(plan.newTasks)")
                    LabeledContent("Уже есть без изменений", value: "\(plan.unchanged)")
                    Text("Текущие записи сохранятся. Повторяющиеся записи не дублируются; при конфликте восстановление остановится.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Восстановить") { confirming = true }
                        .disabled(plan.newTags + plan.newProjects + plan.newTasks == 0)
                    Button("Отмена", role: .cancel) { self.candidate = nil; self.plan = nil }
                }
            }
            if let message { Section { Text(message) } }
            if let error { Section { OrbitErrorMessage(error) } }
        }
        .orbitEditorSurface()
        .navigationTitle("Резервная копия").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: export, contentType: .json, defaultFilename: "Orbit-backup") { result in
            switch result {
            case .success: message = "Копия сохранена."; error = nil
            case .failure(let failure): error = failure.localizedDescription
            }
            export = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= OrbitBackup.maximumBytes else { throw BackupError.invalid("Файл больше 20 МБ.") }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: OrbitBackup.maximumBytes + 1) ?? Data()
                let value = try OrbitBackup.decode(data)
                let preview = try model.backupPlan(value)
                candidate = value; plan = preview; error = nil
            } catch { candidate = nil; plan = nil; self.error = error.localizedDescription }
        }
        .confirmationDialog("Добавить записи из копии?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Восстановить") {
                guard let candidate else { return }
                do {
                    try model.restoreBackup(candidate)
                    self.candidate = nil; plan = nil; error = nil
                    message = "Восстановление завершено. Напоминания обновлены с учётом разрешений устройства."
                } catch { self.error = error.localizedDescription }
            }
            Button("Отмена", role: .cancel) { }
        }
    }
}
