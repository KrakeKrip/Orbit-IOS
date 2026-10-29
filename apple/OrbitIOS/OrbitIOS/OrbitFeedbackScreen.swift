import SwiftUI

struct OrbitFeedbackScreen: View {
    @State private var message = ""
    private var emailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "aatlhnv@gmail.com"
        components.queryItems = [URLQueryItem(name: "subject", value: "Отзыв об Orbit"), URLQueryItem(name: "body", value: report)]
        return components.url
    }
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
                if let emailURL {
                    Link(destination: emailURL) { Label("Написать разработчику", systemImage: "envelope") }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ShareLink(item: report) { Label("Отправить другим способом", systemImage: "square.and.arrow.up") }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Link("Сообщить об ошибке на GitHub", destination: URL(string: "https://github.com/KrakeKrip/Orbit-IOS/issues")!)
            } footer: {
                Text("Откроется почта с адресом aatlhnv@gmail.com. Перед отправкой вы сможете проверить текст. Если почта не настроена, используйте другой способ или GitHub. Задачи и личные данные автоматически не прикладываются.")
            }
        }.navigationTitle("Обратная связь").navigationBarTitleDisplayMode(.inline).orbitEditorSurface()
    }
}
