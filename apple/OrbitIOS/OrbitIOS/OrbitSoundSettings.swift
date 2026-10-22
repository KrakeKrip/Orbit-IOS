import SwiftUI
import UserNotifications
import OrbitCore

struct OrbitSoundSettings: View {
    @Environment(OrbitReminderScheduler.self) private var service
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            Section {
                ForEach(ReminderSound.allCases, id: \.self) { option in
                    HStack(spacing: 12) {
                        Button { service.setSound(option) } label: {
                            HStack {
                                Text(option.title).foregroundStyle(.primary)
                                Spacer()
                                if service.sound == option {
                                    Image(systemName: "checkmark").foregroundStyle(Color.orbitAccent)
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(service.sound == option ? [.isSelected] : [])
                        .accessibilityIdentifier("reminder-sound-" + option.rawValue)
                        if option != .silent {
                            Button { Task { await service.previewSound(option) } } label: {
                                Image(systemName: "speaker.wave.2")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Прослушать: " + option.title)
                            .accessibilityIdentifier("reminder-sound-preview-" + option.rawValue)
                        }
                    }
                }
            } footer: {
                Text("Один звук для всех напоминаний, включая уже назначенные. Режим без звука, громкость и настройки уведомлений iPhone влияют на воспроизведение. Для прослушивания стандартного звука нужно разрешение на уведомления.")
            }
            if let error = service.soundPreviewError {
                Section { OrbitErrorMessage(error) }
            }
        }
        .orbitEditorSurface()
        .navigationTitle("Звук уведомлений")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { service.stopSoundPreview() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { service.stopSoundPreview() }
        }
    }
}
