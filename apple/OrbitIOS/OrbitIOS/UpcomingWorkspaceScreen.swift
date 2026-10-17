import Combine
import SwiftUI
import OrbitCore

/// The «Предстоящее» section (NATIVE-NAV-002): one shared model/store with
/// two switchable presentations over an independently selected civil day —
/// the large-row list (`UpcomingListScreen`, an inclusive 7-day window from
/// the selected day) and the accepted day calendar (`CalendarDayScreen` in
/// its browsing context). This view is the single Upcoming selection owner:
/// the selected day starts at the local Gregorian today and the mode at
/// «Список» initially; mode is persisted independently in UserDefaults.
/// The selected day is session state, never persisted into tasks/store, and
/// stay independent of the Today section's current day and mode.
/// Appear/active reloads of the shared model never reset the manual
/// selection. NATIVE-NAV-002-R1: this view also owns the refreshed
/// reference current local day (appear/scene active/lightweight timer) that
/// drives the contextual «Сегодня» jump; refreshing the reference never
/// resets the manual selection or the mode.
struct UpcomingWorkspaceScreen: View {
    let model: IOSInboxModel

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("orbit.ui.upcoming.calendar") private var showsCalendar = false
    @State private var selectedDay: String = TaskDaySelection.currentDay()
    @State private var referenceDay: String = TaskDaySelection.currentDay()
    private let dayRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if showsCalendar {
                CalendarDayScreen(
                    model: model,
                    todayMode: $showsCalendar,
                    browsingDay: $selectedDay,
                    referenceDay: referenceDay
                )
            } else {
                UpcomingListScreen(
                    model: model,
                    selectedDay: $selectedDay,
                    showsCalendar: $showsCalendar,
                    referenceDay: referenceDay
                )
            }
        }
        // NATIVE-ADD-002: one shared «+»/create sheet for both presentations.
        // The preset is the section's existing selected day — the one
        // selection owner is never duplicated, and creating never resets the
        // selection or the mode.
        .orbitCreateAction(model: model, datePreset: { selectedDay })
        .onChange(of: showsCalendar) { _, _ in OrbitHaptics.selection() }
        .onChange(of: selectedDay) { _, _ in OrbitHaptics.selection() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 70, abs(dx) > abs(dy) * 1.6 else { return }
                moveDay(dx < 0 ? 1 : -1)
            }
        )
        .onAppear {
            // Keep the rows in sync after external changes; the selected day
            // and the mode are presentation state and are never reset here.
            model.reload()
            refreshReferenceDay()
        }
        .onReceive(dayRefreshTimer) { _ in
            // Midnight/local-zone changes reach the jump visibility within
            // half a minute without touching the user's selection.
            refreshReferenceDay()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshReferenceDay()
            }
        }
    }

    private func moveDay(_ offset: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let current = TaskPlannedDate.date(fromCivilDateString: selectedDay, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: offset, to: current) else { return }
        let candidate = TaskPlannedDate.civilDateString(from: next, calendar: calendar)
        guard TaskPlannedDate.isValid(candidate) else { return }
        selectedDay = candidate
    }

    /// Refreshes the current local Gregorian day reference only. The manual
    /// selection and the mode are the user's and are never rewritten here.
    private func refreshReferenceDay() {
        referenceDay = TaskDaySelection.currentDay()
    }
}

/// Compact native view menu; the icon follows the workspace's current mode.
/// Its binding remains owned by the section and survives tab changes.
struct UpcomingModeSwitcher: View {
    @Binding var showsCalendar: Bool

    var body: some View {
        OrbitViewModeMenu(showsCalendar: $showsCalendar, identifier: "upcoming-mode-switcher")
    }
}
