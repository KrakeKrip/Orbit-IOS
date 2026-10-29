import SwiftUI

struct OrbitFeedbackScreen: View {
    @State private var message = ""
    private var report: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Orbit \(version) (\(build))\n\n" + message
    }
    var body: some View {
        Form {
            Section("Ошибка или предложение") {
                TextField("Что случилось или что хотелось бы улучшить?", text: $message, axis: .vertical)
                    .lineLimit(5...12)
            }
            Section {
                ShareLink(item: report) { Label("Поделиться отзывом", systemImage: "square.and.arrow.up") }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Link("Открыть обсуждение на GitHub", destination: URL(string: "https://github.com/KrakeKrip/Orbit-IOS/issues")!)
            } footer: {
                Text("Выберите, кому отправить отзыв. Задачи и личные данные автоматически не прикладываются. В TestFlight можно также отправить снимок экрана разработчику.")
            }
        }.navigationTitle("Обратная связь").navigationBarTitleDisplayMode(.inline).orbitEditorSurface()
    }
}
