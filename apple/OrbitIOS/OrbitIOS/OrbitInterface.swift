import SwiftUI
import UIKit

extension Calendar {
    static var orbitCivil: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = .current
        return value
    }
}

/// Appearance belongs to this device, independently of the task database.
enum OrbitAppearance: String, CaseIterable, Identifiable {
    case system, light, ivory, dark, oled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Как на устройстве"
        case .light: "Светлая"
        case .ivory: "Слоновая кость"
        case .dark: "Тёмная"
        case .oled: "Чёрная OLED"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .ivory: .light
        case .dark, .oled: .dark
        }
    }
    var canvas: Color {
        switch self {
        case .system: Color(uiColor: .systemBackground)
        case .light: .white
        case .ivory: Color(red: 0.98, green: 0.96, blue: 0.91)
        case .dark: Color(red: 0.085, green: 0.085, blue: 0.10)
        case .oled: .black
        }
    }
}

private struct OrbitAppearanceKey: EnvironmentKey {
    static let defaultValue = OrbitAppearance.system
}
extension EnvironmentValues {
    var orbitAppearance: OrbitAppearance {
        get { self[OrbitAppearanceKey.self] }
        set { self[OrbitAppearanceKey.self] = newValue }
    }
}

@MainActor
enum OrbitHaptics {
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "orbit.ui.haptics") as? Bool ?? true
    }
    private static let timelineGenerator = UISelectionFeedbackGenerator()
    static func prepareTimeline() {
        guard enabled else { return }
        timelineGenerator.prepare()
    }
    /// A light tick for a newly snapped time/duration, rather than every pan frame.
    static func timelineStep() {
        guard enabled else { return }
        timelineGenerator.selectionChanged()
        timelineGenerator.prepare()
    }
    static func selection() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
    }
    static func longPress() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
    }
}

private struct OrbitIconStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass).buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
        } else {
            content.buttonStyle(.bordered).buttonBorderShape(.circle)
        }
    }
}
private struct OrbitPrimaryStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule).controlSize(.large).tint(.orbitAccent)
        } else {
            content.buttonStyle(.borderedProminent).controlSize(.large).tint(.orbitAccent)
        }
    }
}
private struct OrbitSecondaryStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
private struct OrbitEditorSurface: ViewModifier {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.colorScheme) private var inheritedColorScheme
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(appearance.canvas)
            // Keep the system sheet's own backing surface and transition.
            // A presentationBackground preference can repaint the full host
            // before the sheet starts moving on current iOS releases.
            .environment(\.colorScheme, appearance.colorScheme ?? inheritedColorScheme)
    }
}
private struct OrbitLongPressFeedback: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in OrbitHaptics.longPress() }
        )
    }
}
extension View {
    func orbitIconStyle() -> some View { modifier(OrbitIconStyle()) }
    func orbitPrimaryStyle() -> some View { modifier(OrbitPrimaryStyle()) }
    func orbitSecondaryStyle() -> some View { modifier(OrbitSecondaryStyle()) }
    func orbitEditorSurface() -> some View { modifier(OrbitEditorSurface()) }
    func orbitLongPressFeedback() -> some View { modifier(OrbitLongPressFeedback()) }
    func orbitMenuFeedback() -> some View {
        simultaneousGesture(TapGesture().onEnded { OrbitHaptics.selection() })
    }
}

/// One compact menu replaces the segmented picker in both workspaces.
struct OrbitViewModeMenu: View {
    @Binding var showsCalendar: Bool
    let identifier: String
    var body: some View {
        Menu {
            Picker("Вид отображения", selection: $showsCalendar) {
                Label("Список", systemImage: "list.bullet").tag(false)
                Label("Календарь", systemImage: "calendar").tag(true)
            }
        } label: {
            Image(systemName: showsCalendar ? "calendar" : "list.bullet")
                .font(.system(size: 18, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
        }
        .orbitIconStyle()
        .orbitMenuFeedback()
        .accessibilityLabel("Вид: \(showsCalendar ? "Календарь" : "Список")")
        .accessibilityIdentifier(identifier)
    }
}

struct OrbitSettingsButton: View {
    @State private var showsSettings = false
    var body: some View {
        Button {
            OrbitHaptics.selection()
            showsSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .orbitIconStyle()
        .accessibilityLabel("Настройки")
        .accessibilityIdentifier("orbit-settings")
        .sheet(isPresented: $showsSettings) { OrbitSettingsSheet() }
    }
}

struct OrbitSettingsSheet: View {
    @Environment(OrbitReminderScheduler.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var inheritedColorScheme
    @AppStorage("orbit.ui.appearance") private var appearanceRaw = OrbitAppearance.system.rawValue
    @AppStorage("orbit.ui.haptics") private var haptics = true
    private var selectedAppearance: OrbitAppearance {
        OrbitAppearance(rawValue: appearanceRaw) ?? .system
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Оформление") {
                    ForEach(OrbitAppearance.allCases) { option in
                        Button {
                            appearanceRaw = option.rawValue
                            OrbitHaptics.selection()
                        } label: {
                            HStack {
                                Circle().fill(option.canvas)
                                    .overlay(Circle().stroke(.secondary.opacity(0.4), lineWidth: 1))
                                    .frame(width: 22, height: 22)
                                Text(option.title).foregroundStyle(.primary)
                                Spacer()
                                if appearanceRaw == option.rawValue {
                                    Image(systemName: "checkmark").foregroundStyle(Color.orbitAccent)
                                }
                            }
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(appearanceRaw == option.rawValue ? [.isSelected] : [])
                    }
                }
                Section("Уведомления") {
                    ReminderPermissionView(service: reminders)
                }
                Section("Отклик") {
                    Toggle("Виброотклик", isOn: $haptics)
                }
            }
            .orbitEditorSurface()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .environment(\.orbitAppearance, selectedAppearance)
        .environment(\.colorScheme, selectedAppearance.colorScheme ?? inheritedColorScheme)
    }
}
