import SwiftUI
import Combine
import OrbitCore

@main
struct OrbitIOSApp: App {
    private enum Launch {
        case ready(IOSInboxModel)
        case openFailed(String)
    }

    private enum Tab: Hashable {
        case today
        case inbox
        case upcoming
        case projects
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var launch: Launch
    @AppStorage("orbit.ui.appearance") private var appearanceRaw = OrbitAppearance.system.rawValue
    private var appearance: OrbitAppearance { OrbitAppearance(rawValue: appearanceRaw) ?? .system }
    private let reminderTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var selectedTab: Tab = .today

    init() {
        _launch = State(initialValue: Self.openLaunchStore())
    }

    /// Opens the app's own sandbox store (explicit URL, no launch overrides).
    /// On failure shows an explicit error state and never deletes the store
    /// or falls back to an in-memory database.
    private static func openLaunchStore() -> Launch {
        do {
            let store = try IOSStore.open()
            return .ready(IOSInboxModel(store: store))
        } catch {
            return .openFailed(IOSInboxFormatting.openMessage(error))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let model):
                TabView(selection: $selectedTab) {
                    TodayWorkspaceScreen(model: model)
                        .tabItem {
                            Label("Сегодня", systemImage: "sun.max")
                        }
                        .tag(Tab.today)
                    InboxScreen(model: model)
                        .tabItem {
                            Label("Входящие", systemImage: "tray")
                        }
                        .tag(Tab.inbox)
                    UpcomingWorkspaceScreen(model: model)
                        .tabItem {
                            Label("Предстоящее", systemImage: "calendar")
                        }
                        .tag(Tab.upcoming)
                    ProjectsScreen(model: model)
                        .tabItem { Label("Проекты", systemImage: "folder") }
                        .tag(Tab.projects)
                }
                .environment(model.reminders)
                .onAppear { model.reminders.start() }
                .onReceive(reminderTimer) { _ in
                    if scenePhase == .active { model.reminders.refresh() }
                }
                .tint(.orbitAccent)
                .environment(\.orbitAppearance, appearance)
                .preferredColorScheme(appearance.colorScheme)
                .onChange(of: selectedTab) { _, _ in OrbitHaptics.selection() }
                .onChange(of: scenePhase) { _, phase in
                    // Returning to the foreground re-reads the shared store so
                    // all tabs reflect persisted truth.
                    if phase == .active {
                        model.reload()
                    }
                }
            case .openFailed(let message):
                StoreFailureView(message: message)
            }
        }
    }
}
