import SwiftUI
import UIKit

/// Icon selection is independent of the interface theme and task store.
struct OrbitAppIcon: Equatable {
    enum Background: String, CaseIterable, Identifiable {
        case ivory, white, night
        var id: Self { self }
        var title: String {
            switch self { case .ivory: "Слоновая кость"; case .white: "Белый"; case .night: "Ночной" }
        }
    }
    enum Accent: String, CaseIterable, Identifiable {
        case coral, sage, blue, lilac
        var id: Self { self }
        var title: String {
            switch self { case .coral: "Коралл"; case .sage: "Шалфей"; case .blue: "Синий"; case .lilac: "Сирень" }
        }
        var color: Color {
            switch self {
            case .coral: Color(red: 0.898, green: 0.424, blue: 0.361)
            case .sage: Color(red: 0.329, green: 0.482, blue: 0.408)
            case .blue: Color(red: 0.322, green: 0.494, blue: 0.667)
            case .lilac: Color(red: 0.537, green: 0.439, blue: 0.659)
            }
        }
    }
    var background: Background = .ivory
    var accent: Accent = .coral
    var key: String { background.rawValue + "-" + accent.rawValue }
    var title: String { background.title + " · " + accent.title }
    var previewName: String { "IconPreview-" + key }
    var alternateName: String? {
        self == Self() ? nil : "Icon" + background.rawValue.capitalized + accent.rawValue.capitalized
    }
    static func resolve(_ name: String?) -> Self? {
        for background in Background.allCases {
            for accent in Accent.allCases {
                let icon = Self(background: background, accent: accent)
                if icon.alternateName == name { return icon }
            }
        }
        return nil
    }
}

struct OrbitAppIconSettings: View {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = OrbitAppIcon()
    @State private var installedName: String?
    @State private var applying = false
    @State private var error: String?
    @State private var applied = false
    private var supported: Bool { UIApplication.shared.supportsAlternateIcons }
    private var unchanged: Bool { draft.alternateName == installedName }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(draft.previewName).resizable().interpolation(.high)
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(appearance.secondaryText.opacity(0.25)))
                        .accessibilityLabel("Предпросмотр: " + draft.title)
                    Text(draft.title).font(.headline).multilineTextAlignment(.center)
                    Text("Установлена: " + (OrbitAppIcon.resolve(installedName)?.title ?? "Другая иконка"))
                        .font(.footnote).foregroundStyle(appearance.secondaryText).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            Section("Фон") {
                ForEach(OrbitAppIcon.Background.allCases) { background in
                    option(background.title, selected: draft.background == background) {
                        draft.background = background; resetFeedback()
                    }
                }
            }
            Section("Акцент") {
                ForEach(OrbitAppIcon.Accent.allCases) { accent in
                    option(accent.title, selected: draft.accent == accent, swatch: accent.color) {
                        draft.accent = accent; resetFeedback()
                    }
                }
            }
            Section {
                if !supported {
                    Text("Смена иконки недоступна на этом устройстве.")
                        .foregroundStyle(appearance.secondaryText)
                }
                if let error { OrbitErrorMessage(error).accessibilityIdentifier("app-icon-error") }
                if applied {
                    Label("Иконка применена", systemImage: "checkmark.circle")
                        .accessibilityIdentifier("app-icon-success")
                }
                Text("Выбор иконки не меняет оформление Orbit. Системное оформление значков на домашнем экране может менять её вид.")
                    .font(.footnote).foregroundStyle(appearance.secondaryText)
            }
        }
        .disabled(applying)
        .orbitEditorSurface()
        .navigationTitle("Иконка приложения")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: apply) {
                HStack {
                    if applying { ProgressView().tint(.white) }
                    Text(applying ? "Применяем…" : "Применить иконку").fontWeight(.semibold)
                }.frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent).tint(Color.orbitAccentFill)
            .disabled(applying || !supported || unchanged)
            .accessibilityIdentifier("app-icon-apply")
            .padding(.horizontal, 20).padding(.vertical, 10).background(appearance.canvas)
        }
        .onAppear {
            installedName = UIApplication.shared.alternateIconName
            draft = OrbitAppIcon.resolve(installedName) ?? OrbitAppIcon()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !applying { installedName = UIApplication.shared.alternateIconName }
        }
    }

    private func option(_ title: String, selected: Bool, swatch: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let swatch {
                    Circle().fill(swatch).frame(width: 24, height: 24)
                        .overlay(Circle().stroke(appearance.secondaryText.opacity(0.5), lineWidth: 1))
                }
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.orbitAccent : appearance.secondaryText)
            }.frame(minHeight: 36).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func resetFeedback() { error = nil; applied = false }

    private func apply() {
        guard supported, !applying, !unchanged else { return }
        applying = true; resetFeedback()
        let requestedName = draft.alternateName
        UIApplication.shared.setAlternateIconName(requestedName) { failure in
            Task { @MainActor in
                applying = false
                installedName = UIApplication.shared.alternateIconName
                if let failure {
                    error = "Не удалось изменить иконку. " + failure.localizedDescription
                } else if installedName == requestedName {
                    applied = true
                } else {
                    error = "Система не подтвердила смену иконки. Попробуйте ещё раз."
                }
            }
        }
    }
}
