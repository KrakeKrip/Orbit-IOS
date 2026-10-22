import SwiftUI
import UIKit

struct OrbitAppearanceSettings: View {
    @Environment(\.orbitAppearance) private var appearance
    @AppStorage("orbit.ui.appearance") private var appearanceRaw = OrbitAppearance.system.rawValue
    @AppStorage("orbit.ui.appearance.systemLight") private var lightRaw = OrbitAppearance.light.rawValue
    @AppStorage("orbit.ui.appearance.systemDark") private var darkRaw = OrbitAppearance.dark.rawValue
    @State private var draftLight: OrbitAppearance = .light
    @State private var draftDark: OrbitAppearance = .dark
    @Environment(\.scenePhase) private var scenePhase
    @State private var systemScheme: ColorScheme = .light
    @State private var draft: OrbitAppearance = .system
    private var unchanged: Bool {
        draft.rawValue == appearanceRaw && draftLight == .systemLight(lightRaw) && draftDark == .systemDark(darkRaw)
    }
    private var preview: OrbitAppearance {
        draft == .system ? .systemTheme(scheme: systemScheme, light: draftLight.rawValue, dark: draftDark.rawValue) : draft
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Сегодня").font(.title3.bold())
                        Spacer()
                        Image(systemName: "ellipsis").foregroundStyle(Color.orbitAccent)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Circle().stroke(preview.secondaryText, lineWidth: 1.5).frame(width: 20, height: 20)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Спланировать день").font(.body.weight(.medium))
                            Text("10:00–11:00").font(.footnote).foregroundStyle(preview.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }.padding(12).background(preview.surface, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Text(preview.title).font(.footnote).foregroundStyle(preview.secondaryText)
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.orbitAccent)
                    }
                }
                .padding(20).foregroundStyle(preview.eventText)
                .background(preview.canvas, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(appearance.secondaryText.opacity(0.25)))
                .padding(.vertical, 6)
                .environment(\.colorScheme, preview.colorScheme ?? systemScheme)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Предпросмотр темы: " + preview.title)
            }
            Section("Тема приложения") {
                ForEach(OrbitAppearance.allCases) { option in
                    Button {
                        draft = option
                        OrbitHaptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(option.canvas)
                                .overlay(Circle().stroke(appearance.secondaryText.opacity(0.5), lineWidth: 1))
                                .frame(width: 26, height: 26)
                            Text(option.title).foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Image(systemName: draft == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draft == option ? Color.orbitAccent : appearance.secondaryText)
                        }.frame(minHeight: 36).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(draft == option ? .isSelected : [])
                }
            }
            if draft == .system {
                Section {
                    Picker("Светлый режим iPhone", selection: $draftLight) {
                        Text("Светлая").tag(OrbitAppearance.light)
                        Text("Слоновая кость").tag(OrbitAppearance.ivory)
                    }.accessibilityIdentifier("system-light-theme")
                    Picker("Тёмный режим iPhone", selection: $draftDark) {
                        Text("Тёмная").tag(OrbitAppearance.dark)
                        Text("Чёрная OLED").tag(OrbitAppearance.oled)
                    }.accessibilityIdentifier("system-dark-theme")
                } header: { Text("Как на устройстве") } footer: {
                    Text("Orbit переключается между этими темами вместе со светлым и тёмным режимом iPhone.")
                }
            }
            Section {
                Text("Текущая тема: " + (OrbitAppearance(rawValue: appearanceRaw) ?? .system).title)
                    .font(.footnote).foregroundStyle(appearance.secondaryText)
                Text("Тема меняет оформление Orbit. Иконка приложения выбирается отдельно.")
                    .font(.footnote).foregroundStyle(appearance.secondaryText)
            }
        }
        .orbitEditorSurface()
        .navigationTitle("Оформление")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                lightRaw = draftLight.rawValue
                darkRaw = draftDark.rawValue
                appearanceRaw = draft.rawValue
                OrbitHaptics.selection()
            } label: {
                Text("Применить тему").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent).tint(Color.orbitAccentFill)
            .disabled(unchanged).accessibilityIdentifier("appearance-apply")
            .padding(.horizontal, 20).padding(.vertical, 10).background(appearance.canvas)
        }
        .onAppear {
            draft = OrbitAppearance(rawValue: appearanceRaw) ?? .system
            draftLight = .systemLight(lightRaw)
            draftDark = .systemDark(darkRaw)
            refreshSystemScheme()
        }
        .onChange(of: appearance) { _, _ in refreshSystemScheme() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSystemScheme() }
        }
    }

    private func refreshSystemScheme() {
        systemScheme = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}
