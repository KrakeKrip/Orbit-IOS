import SwiftUI
import OrbitCore

/// Week navigation above an agenda of civil days, including empty days.
/// Rows and editors use the same model/UUIDs as every other presentation.
struct UpcomingAgendaScreen: View {
    let model: IOSInboxModel
    @Binding var selectedDay: String
    @Binding var showsCalendar: Bool
    @Binding var showsAgenda: Bool
    let referenceDay: String
    @Environment(\.orbitAppearance) private var appearance
    @State private var anchorDay: String
    @State private var dayCount = 56
    @State private var editor: InboxSheetPresentation?
    @State private var createDay: AgendaCreateDay?
    private let calendar = Calendar.orbitCivil

    init(model: IOSInboxModel, selectedDay: Binding<String>, showsCalendar: Binding<Bool>,
         showsAgenda: Binding<Bool>, referenceDay: String) {
        self.model = model; _selectedDay = selectedDay; _showsCalendar = showsCalendar
        _showsAgenda = showsAgenda; self.referenceDay = referenceDay
        _anchorDay = State(initialValue: selectedDay.wrappedValue)
    }

    private struct AgendaCreateDay: Identifiable {
        let day: String
        var id: String { day }
    }

    private func shift(_ day: String, by offset: Int) -> String? {
        guard let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
        let value = TaskPlannedDate.civilDateString(from: next, calendar: calendar)
        return TaskPlannedDate.isValid(value) ? value : nil
    }

    private var days: [String] { (0..<dayCount).compactMap { shift(anchorDay, by: $0) } }
    private var week: [String?] {
        guard let date = TaskPlannedDate.date(fromCivilDateString: selectedDay, calendar: calendar) else { return [] }
        let mondayOffset = (calendar.component(.weekday, from: date) + 5) % 7
        return (0..<7).map { shift(selectedDay, by: $0 - mondayOffset) }
    }
    private var pickerDate: Binding<Date> {
        Binding(get: { TaskPlannedDate.date(fromCivilDateString: selectedDay, calendar: calendar)! },
                set: { selectedDay = TaskPlannedDate.civilDateString(from: $0, calendar: calendar) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: $showsAgenda))
                weekNavigation
                Divider()
                if let message = model.writeError ?? model.listError {
                    Text(message).font(.footnote).foregroundStyle(.red).padding(8)
                }
                ScrollViewReader { proxy in
                    List {
                        ForEach(days, id: \.self) { day in
                            Section {
                                // A regular header row avoids native Section
                                // header + empty-row minimums around empty days.
                                HStack(spacing: 4) {
                                    Text(dayCaption(day)).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(day == referenceDay ? Color.primary : .secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Button {
                                        createDay = AgendaCreateDay(day: day)
                                    } label: {
                                        Image(systemName: "plus").font(.body.weight(.medium))
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(model.isSelecting)
                                    .accessibilityLabel("Добавить задачу на \(RussianDateCaption.label(day))")
                                }
                                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                                .listRowBackground(appearance.canvas)
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    if day == days.last, let last = days.last, shift(last, by: 1) != nil {
                                        dayCount += 28
                                    }
                                }
                                ForEach(TaskDaySelection.tasks(onDay: day, in: model.tasks)) { task in
                                    InboxRowView(task: task, model: model, showsDateLabel: false) {
                                        editor = .date(task)
                                    } onEditInterval: {
                                        editor = .interval(task)
                                    }
                                }
                            }
                            .id(day)
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(0)
                    .contentMargins(.top, 4, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .onChange(of: selectedDay) { _, day in
                        if !days.contains(day) { anchorDay = day; dayCount = 56 }
                        DispatchQueue.main.async { proxy.scrollTo(day, anchor: .top) }
                    }
                }
            }
            .background(appearance.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { item in
                switch item {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
            .sheet(item: $createDay) { value in
                TaskCreateSheet(model: model, datePreset: value.day)
            }
        }
    }

    private var weekNavigation: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                MarkedDatePicker(selection: pickerDate, taskDays: Set(model.tasks.compactMap(\.plannedDate)))
                Spacer(minLength: 0)
                if selectedDay != referenceDay {
                    Button("Сегодня") { selectedDay = referenceDay }.font(.footnote)
                }
                Button { if let day = shift(selectedDay, by: -7) { selectedDay = day } } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 44)
                }
                .disabled(shift(selectedDay, by: -7) == nil)
                .accessibilityLabel("Предыдущая неделя")
                Button { if let day = shift(selectedDay, by: 7) { selectedDay = day } } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 44)
                }
                .disabled(shift(selectedDay, by: 7) == nil)
                .accessibilityLabel("Следующая неделя")
            }
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 2) {
                        Text(["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"][index])
                            .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        if let day, let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar) {
                            Button { selectedDay = day } label: {
                                VStack(spacing: 2) {
                                    Text(String(calendar.component(.day, from: date)))
                                        .font(.body.weight(day == selectedDay ? .semibold : .regular))
                                        .frame(width: 32, height: 32)
                                        .foregroundStyle(day == selectedDay ? Color.white : .primary)
                                        .background(day == selectedDay ? Color.orbitAccent : .clear, in: Circle())
                                    Circle().fill(model.tasks.contains { $0.plannedDate == day } ? Color.orbitAccent : .clear)
                                        .frame(width: 4, height: 4)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel(RussianDateCaption.label(day))
                            .accessibilityAddTraits(day == selectedDay ? [.isSelected] : [])
                        } else { Color.clear.frame(height: 44) }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func dayCaption(_ day: String) -> String {
        guard let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar) else { return day }
        let label = date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "ru_RU")))
        let weekday = date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ru_RU")))
        let relative = day == referenceDay ? " · сегодня" : (day == shift(referenceDay, by: 1) ? " · завтра" : "")
        return "\(label)\(relative) · \(weekday)"
    }
}
