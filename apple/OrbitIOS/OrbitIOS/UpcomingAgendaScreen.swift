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
    @State private var scrollRequest: AgendaScrollRequest?
    @State private var earliestAllowedDay: String
    @State private var isNavigating = false
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
        _earliestAllowedDay = State(initialValue: selectedDay.wrappedValue)
    }

    private struct AgendaScrollRequest: Equatable {
        let day: String
        let token = UUID()
    }

    private struct AgendaDayFrames: PreferenceKey {
        static var defaultValue: [String: CGRect] { [:] }
        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
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
                set: { navigate(to: TaskPlannedDate.civilDateString(from: $0, calendar: calendar)) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: $showsAgenda))
                weekNavigation
                OverdueTaskBlock(model: model)
                Divider()
                if let message = model.writeError ?? model.listError {
                    Text(message).font(.footnote).foregroundStyle(.red).padding(8)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(days, id: \.self) { day in
                                VStack(spacing: 0) {
                                    dayHeader(day)
                                    ForEach(TaskDaySelection.tasks(onDay: day, in: model.tasks)) { task in
                                        InboxRowView(task: task, model: model, showsDateLabel: false) {
                                            editor = .date(task)
                                        } onEditInterval: {
                                            editor = .interval(task)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                        .background(model.isSelecting && model.selectedTaskIDs.contains(task.id)
                                            ? Color.orbitAccent.opacity(0.12) : .clear)
                                        Divider().padding(.leading, 74).padding(.trailing, 16)
                                    }
                                }
                                .id(day)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(key: AgendaDayFrames.self,
                                            value: [day: geometry.frame(in: .named("agenda-viewport"))])
                                    }
                                }
                                .onAppear {
                                    if day == days.last, let last = days.last, shift(last, by: 1) != nil {
                                        dayCount += 28
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .coordinateSpace(name: "agenda-viewport")
                    .onPreferenceChange(AgendaDayFrames.self) { frames in
                        if isNavigating, let request = scrollRequest {
                            // Wait for the requested section to reach the top;
                            // old frames must not immediately lock it out again.
                            guard let frame = frames[request.day],
                                  frame.minY <= 4, frame.maxY > 0 else { return }
                            isNavigating = false
                        }
                        guard let first = frames.filter({ $0.value.maxY > 0 })
                            .min(by: { $0.value.minY < $1.value.minY })?.key else { return }
                        if first < earliestAllowedDay {
                            proxy.scrollTo(earliestAllowedDay, anchor: .top)
                            return
                        }
                        // Only fully departed past days advance the boundary.
                        // Today and future days remain freely scrollable back.
                        if earliestAllowedDay < referenceDay, first > earliestAllowedDay {
                            earliestAllowedDay = min(first, referenceDay)
                        }
                        guard let top = frames.filter({ $0.value.maxY > 22 })
                            .min(by: { $0.value.minY < $1.value.minY })?.key,
                              selectedDay != top else { return }
                        selectedDay = top
                    }
                    .onChange(of: scrollRequest) { _, request in
                        guard let request else { return }
                        proxy.scrollTo(request.day, anchor: .top)
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
                    Button("Сегодня") { navigate(to: referenceDay) }.font(.footnote)
                }
                Button { if let day = adjacentWeek(-1) { navigate(to: day) } } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 44)
                }
                .disabled(adjacentWeek(-1) == nil)
                .accessibilityLabel("Предыдущая неделя")
                Button { if let day = adjacentWeek(1) { navigate(to: day) } } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 44)
                }
                .disabled(adjacentWeek(1) == nil)
                .accessibilityLabel("Следующая неделя")
            }
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 2) {
                        Text(["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"][index])
                            .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        if let day, let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar) {
                            Button { navigate(to: day) } label: {
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
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
            guard !model.isSelecting,
                  abs(value.translation.width) >= 60,
                  abs(value.translation.width) > abs(value.translation.height) * 1.6,
                  let day = adjacentWeek(value.translation.width < 0 ? 1 : -1) else { return }
            navigate(to: day)
        })
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    /// Week paging always lands on Monday, rather than preserving the
    /// weekday of whichever section happens to be at the top of the agenda.
    private func adjacentWeek(_ direction: Int) -> String? {
        guard let date = TaskPlannedDate.date(fromCivilDateString: selectedDay, calendar: calendar) else { return nil }
        let offset = (calendar.component(.weekday, from: date) + 5) % 7
        return shift(selectedDay, by: direction * 7 - offset)
    }

    private func navigate(to day: String) {
        guard TaskPlannedDate.isValid(day) else { return }
        model.endSelection()
        if day < referenceDay || !days.contains(day) {
            anchorDay = day; dayCount = 56
        } else if anchorDay < referenceDay {
            anchorDay = referenceDay
        }
        earliestAllowedDay = anchorDay
        isNavigating = true
        // Also works when tapping the already highlighted day: its section
        // is aligned to the top without depending on a binding change.
        scrollRequest = AgendaScrollRequest(day: day)
        if selectedDay != day { selectedDay = day }
        OrbitHaptics.selection()
    }

    private func dayHeader(_ day: String) -> some View {
        HStack(spacing: 4) {
            Text(dayCaption(day)).font(.subheadline.weight(.semibold))
                .foregroundStyle(day == referenceDay ? Color.primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button { createDay = AgendaCreateDay(day: day) } label: {
                Image(systemName: "plus").font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .disabled(model.isSelecting)
            .accessibilityLabel("Добавить задачу на \(RussianDateCaption.label(day))")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }

    private func dayCaption(_ day: String) -> String {
        guard let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar) else { return day }
        let label = date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "ru_RU")))
        let weekday = date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ru_RU")))
        let relative = day == referenceDay ? " · сегодня" : (day == shift(referenceDay, by: 1) ? " · завтра" : "")
        return "\(label)\(relative) · \(weekday)"
    }
}
