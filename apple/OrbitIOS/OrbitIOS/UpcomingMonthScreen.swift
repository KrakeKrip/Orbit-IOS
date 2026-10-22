import SwiftUI
import OrbitCore

/// Month overview shares the existing civil-date grid, task rows and selected day.
struct UpcomingMonthScreen: View {
    let model: IOSInboxModel
    @Binding var selectedDay: String
    @Binding var showsCalendar: Bool
    @Binding var showsAgenda: Bool
    let referenceDay: String
    @Environment(\.orbitAppearance) private var appearance
    @State private var presentation: InboxSheetPresentation?

    private var selection: Binding<Date> {
        Binding(get: { TaskPlannedDate.date(fromCivilDateString: selectedDay, calendar: .orbitCivil)! },
                set: { selectedDay = TaskPlannedDate.civilDateString(from: $0, calendar: .orbitCivil) })
    }
    private var tasks: [OrbitTask] { TaskDaySelection.tasks(onDay: selectedDay, in: model.tasks) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: $showsAgenda)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Выбрано: " + RussianDateCaption.label(selectedDay))
                        if selectedDay != referenceDay { Button("Сегодня") { selectedDay = TaskDaySelection.currentDay() }.frame(minHeight: 44) }
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkedMonthCalendar(selection: selection, taskDays: Set(model.tasks.compactMap(\.plannedDate))) {}
                        OverdueTaskBlock(model: model)
                        Divider()
                        Text(RussianDateCaption.label(selectedDay)).font(.headline).padding(.vertical, 8)
                        if let error = model.writeError { OrbitErrorMessage(error) }
                        if let error = model.listError {
                            OrbitTaskLoadFailure(message: error, retry: { model.reload() })
                        } else if tasks.isEmpty {
                            Text("На этот день задач нет").foregroundStyle(appearance.secondaryText).padding(.vertical, 12)
                        } else {
                            ForEach(tasks) { task in
                                InboxRowView(task: task, model: model, showsDateLabel: false) {
                                    presentation = .date(task)
                                } onEditInterval: {
                                    presentation = .interval(task)
                                }
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 16)
                }
                .contentMargins(.bottom, 88, for: .scrollContent)
            }
            .background(appearance.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $presentation) { item in
                switch item {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
        }
    }
}
