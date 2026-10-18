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
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: $showsAgenda))
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkedMonthCalendar(selection: selection, taskDays: Set(model.tasks.compactMap(\.plannedDate))) {}
                        if selectedDay != referenceDay {
                            Button("Сегодня") { selectedDay = TaskDaySelection.currentDay() }
                                .frame(minHeight: 44)
                        }
                        OverdueTaskBlock(model: model)
                        Divider()
                        Text(RussianDateCaption.label(selectedDay)).font(.headline).padding(.vertical, 8)
                        if let error = model.writeError { Text(error).font(.footnote).foregroundStyle(.red) }
                        if let error = model.listError {
                            Text(error).foregroundStyle(.secondary)
                            Button("Повторить") { model.reload() }
                        } else if tasks.isEmpty {
                            Text("На этот день задач нет").foregroundStyle(.secondary).padding(.vertical, 12)
                        } else {
                            ForEach(tasks) { task in
                                InboxRowView(task: task, model: model, showsDateLabel: false) {
                                    presentation = .date(task)
                                } onEditInterval: {
                                    presentation = .interval(task)
                                }
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 110)
                }
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
