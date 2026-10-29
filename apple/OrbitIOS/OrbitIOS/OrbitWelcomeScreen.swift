import SwiftUI

struct OrbitWelcomeScreen: View {
    let reminders: OrbitReminderScheduler
    let finish: () -> Void
    @Environment(\.orbitAppearance) private var appearance
    @State private var requesting = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("IconPreview-ivory-coral")
                    .resizable().scaledToFit().frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                Text("Добро пожаловать в Orbit").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("Задачи и планы — в одном месте.")
                    .foregroundStyle(appearance.secondaryText).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Планируйте свой день", systemImage: "calendar")
                    Label("Собирайте задачи в проекты", systemImage: "folder")
                    Label("Получайте напоминания вовремя", systemImage: "bell")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Три полезных жеста").font(.headline)
                    Label("Удерживайте пустое место календаря и потяните — выберите время новой задачи.", systemImage: "hand.draw")
                    Label("Удерживайте задачу для переноса. Потяните за кружок на границе, чтобы изменить длительность.", systemImage: "arrow.up.and.down")
                    Label("В названии можно написать «завтра в 15:00». Нажмите «Применить», чтобы перенести распознанное время в план.", systemImage: "text.badge.checkmark")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
                Text("Разрешите уведомления, чтобы Orbit мог напоминать о ваших задачах.")
                    .multilineTextAlignment(.center).foregroundStyle(appearance.secondaryText)
                Button {
                    requesting = true
                    Task { await reminders.requestAuthorization(); requesting = false; finish() }
                } label: {
                    HStack { if requesting { ProgressView() }; Text("Включить уведомления") }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.borderedProminent).disabled(requesting)
                    .accessibilityIdentifier("welcome-notifications")
                Button("Пока без напоминаний", action: finish)
                    .frame(minHeight: 44).disabled(requesting)
                    .accessibilityIdentifier("welcome-skip")
                Text("Можно изменить в настройках").font(.footnote).foregroundStyle(appearance.secondaryText)
            }.padding(28).padding(.top, 36)
        }.background(appearance.canvas).interactiveDismissDisabled()
    }
}
