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

extension OrbitAppearance {
    var surface: Color {
        switch self {
        case .ivory: Color(red: 1, green: 0.99, blue: 0.96)
        case .dark, .oled: Color(red: 0.15, green: 0.15, blue: 0.16)
        default: Color(uiColor: .secondarySystemBackground)
        }
    }
    var eventSurface: Color { surface }
    var eventText: Color { .primary }
    var secondaryText: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.76, alpha: 1) : UIColor(red: 0.37, green: 0.36, blue: 0.34, alpha: 1)
        })
    }
    var eventSecondary: Color { secondaryText }
}
private struct OrbitCalendarActionsKey: EnvironmentKey { static let defaultValue: AnyView? = nil }
private struct OrbitWorkspaceTitleKey: EnvironmentKey { static let defaultValue = "Сегодня" }
private struct OrbitDayTasksKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    var orbitCalendarActions: AnyView? {
        get { self[OrbitCalendarActionsKey.self] }
        set { self[OrbitCalendarActionsKey.self] = newValue }
    }
    var orbitWorkspaceTitle: String {
        get { self[OrbitWorkspaceTitleKey.self] }
        set { self[OrbitWorkspaceTitleKey.self] = newValue }
    }
    var orbitDayTasksAction: (() -> Void)? {
        get { self[OrbitDayTasksKey.self] }
        set { self[OrbitDayTasksKey.self] = newValue }
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
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}
private struct OrbitPrimaryStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule).controlSize(.large).tint(.orbitAccentFill)
        } else {
            content.buttonStyle(.borderedProminent).controlSize(.large).tint(.orbitAccentFill)
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
            .listSectionSpacing(.custom(8))
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
private struct OrbitThreeDayModeKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}
extension EnvironmentValues {
    var orbitThreeDayMode: Binding<Bool>? {
        get { self[OrbitThreeDayModeKey.self] }
        set { self[OrbitThreeDayModeKey.self] = newValue }
    }
}

private struct OrbitMonthModeKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}
extension EnvironmentValues {
    var orbitMonthMode: Binding<Bool>? {
        get { self[OrbitMonthModeKey.self] }
        set { self[OrbitMonthModeKey.self] = newValue }
    }
}

struct OrbitViewModeMenu: View {
    @Binding var showsCalendar: Bool
    let identifier: String
    var agendaMode: Binding<Bool>? = nil
    @Environment(\.orbitThreeDayMode) private var threeDayMode
    @Environment(\.orbitMonthMode) private var monthMode
    private var mode: Binding<Int> {
        Binding(get: { monthMode?.wrappedValue == true ? 4 : (threeDayMode?.wrappedValue == true ? 3 : (agendaMode?.wrappedValue == true ? 2 : (showsCalendar ? 1 : 0))) }, set: { value in
            monthMode?.wrappedValue = value == 4
            threeDayMode?.wrappedValue = value == 3
            agendaMode?.wrappedValue = value == 2
            showsCalendar = value == 1
        })
    }
    private var title: String { mode.wrappedValue == 4 ? "Месяц" : mode.wrappedValue == 3 ? "3 дня" : mode.wrappedValue == 2 ? "Повестка" : (showsCalendar ? "Календарь" : "Список") }
    var body: some View {
        Menu {
            Picker("Вид отображения", selection: mode) {
                Label("Список", systemImage: "list.bullet").tag(0)
                if agendaMode != nil { Label("Повестка", systemImage: "calendar.badge.clock").tag(2) }
                Label("Календарь", systemImage: "calendar").tag(1)
                if threeDayMode != nil { Label("3 дня", systemImage: "rectangle.split.3x1").tag(3) }
                if monthMode != nil { Label("Месяц", systemImage: "calendar.circle").tag(4) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }.font(.subheadline.weight(.medium)).frame(minHeight: 44)

        }
        .buttonStyle(.plain)
        .orbitMenuFeedback()
        .accessibilityLabel("Вид: \(title)")
        .accessibilityIdentifier(identifier)
    }
}

private struct OrbitAllowsTaskSelectionKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var orbitAllowsTaskSelection: Bool {
        get { self[OrbitAllowsTaskSelectionKey.self] }
        set { self[OrbitAllowsTaskSelectionKey.self] = newValue }
    }
}

struct OrbitSettingsButton: View {
    @Environment(IOSInboxModel.self) private var model
    @Environment(\.orbitAllowsTaskSelection) private var allowsSelection
    @State private var showsSettings = false
    @Environment(\.orbitDayTasksAction) private var dayTasksAction
    @Environment(\.orbitCalendarActions) private var calendarActions
    var body: some View {
        Menu {
            Button("Выбрать", systemImage: "checkmark.circle") { model.beginSelection() }
                .disabled(!allowsSelection || model.tasks.isEmpty)
            if let calendarActions { calendarActions }
            if let dayTasksAction { Button("Задачи дня", systemImage: "list.bullet", action: dayTasksAction) }
            Button("Настройки", systemImage: "gearshape") { showsSettings = true }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 20, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .orbitIconStyle()
        .orbitMenuFeedback()
        .accessibilityLabel("Действия")
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
    @AppStorage("orbit.ui.completionSound") private var completionSound = true
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
                    NavigationLink {
                        OrbitSoundSettings()
                    } label: {
                        LabeledContent("Звук", value: reminders.sound.title)
                    }.accessibilityIdentifier("reminder-sound-settings")
                }
                Section("Отклик") {
                    Toggle("Виброотклик", isOn: $haptics)
                    Toggle("Звук выполнения", isOn: $completionSound)
                        .accessibilityIdentifier("completion-sound-toggle")
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

/// One error surface; callers keep their actual message and existing retry action.
struct OrbitErrorMessage: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.footnote).foregroundStyle(Color.orbitError)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(Color.orbitError.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
    }
}
extension Color {
    static var orbitError: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 1) : UIColor(red: 0.72, green: 0.13, blue: 0.12, alpha: 1)
        })
    }
}

struct OrbitTaskLoadFailure: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Задачи недоступны", systemImage: "exclamationmark.triangle")
        } description: {
            OrbitErrorMessage(message)
        } actions: {
            Button("Повторить", action: retry).frame(minHeight: 44).orbitPrimaryStyle()
        }
    }
}
