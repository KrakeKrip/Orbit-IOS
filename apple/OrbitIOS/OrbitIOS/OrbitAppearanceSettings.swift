import SwiftUI
import UIKit

struct OrbitAppearanceSettings: View {
    @Environment(\.orbitAppearance) private var appearance
    @AppStorage("orbit.ui.appearance") private var appearanceRaw = OrbitAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var systemScheme: ColorScheme = .light
    @State private var draft: OrbitAppearance = .system
    private var unchanged: Bool { draft.rawValue == appearanceRaw }

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
                        Circle().stroke(draft.secondaryText, lineWidth: 1.5).frame(width: 20, height: 20)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Спланировать день").font(.body.weight(.medium))
                            Text("10:00–11:00").font(.footnote).foregroundStyle(draft.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }.padding(12).background(draft.surface, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Text(draft.title).font(.footnote).foregroundStyle(draft.secondaryText)
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.orbitAccent)
                    }
                }
                .padding(20).foregroundStyle(draft.eventText)
                .background(draft.canvas, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(appearance.secondaryText.opacity(0.25)))
                .padding(.vertical, 6)
                .environment(\.colorScheme, draft.colorScheme ?? systemScheme)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Предпросмотр темы: " + draft.title)
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
            refreshSystemScheme()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSystemScheme() }
        }
    }

    private func refreshSystemScheme() {
        systemScheme = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}
