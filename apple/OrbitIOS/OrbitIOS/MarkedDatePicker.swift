import SwiftUI
import OrbitCore

/// A bounded month grid with one task-presence marker per planned civil day.
struct MarkedDatePicker: View {
    @Binding var selection: Date
    let taskDays: Set<String>
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            Text(selection.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "ru_RU"))))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать дату")
        .popover(isPresented: $presented) {
            MarkedMonthCalendar(selection: $selection, taskDays: taskDays) { presented = false }
                .frame(width: 308)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Intrinsic height is header + weekday labels + 4/5/6 complete week rows.
/// No UIKit intrinsic-size negotiation or fixed outer height can clip a week.
private struct MarkedMonthCalendar: View {
    @Binding var selection: Date
    let taskDays: Set<String>
    let onSelect: () -> Void
    @State private var month: Date
    @State private var choosingMonth = false
    @State private var jumpYear: Int
    @State private var jumpMonth: Int
    private var calendar: Calendar {
        var value = Calendar.orbitCivil
        value.locale = Locale(identifier: "ru_RU")
        return value
    }
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7)
    private let weekdays = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    init(selection: Binding<Date>, taskDays: Set<String>, onSelect: @escaping () -> Void) {
        _selection = selection
        self.taskDays = taskDays
        self.onSelect = onSelect
        let calendar = Calendar.orbitCivil
        let date = selection.wrappedValue
        _month = State(initialValue: calendar.dateInterval(of: .month, for: date)!.start)
        _jumpYear = State(initialValue: calendar.component(.year, from: date))
        _jumpMonth = State(initialValue: calendar.component(.month, from: date))
    }

    private var days: [Date?] {
        let leading = (calendar.component(.weekday, from: month) + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: month)!
        let dates = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: noon) }
        let trailing = (7 - (leading + count) % 7) % 7
        return Array(repeating: nil, count: leading) + dates + Array(repeating: nil, count: trailing)
    }

    private func shiftedMonth(_ delta: Int) -> Date? {
        guard let date = calendar.date(byAdding: .month, value: delta, to: month),
              (1900...2199).contains(calendar.component(.year, from: date)) else { return nil }
        return date
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Button {
                    jumpYear = calendar.component(.year, from: month)
                    jumpMonth = calendar.component(.month, from: month)
                    choosingMonth.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))))
                            .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                        Image(systemName: choosingMonth ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.orbitAccent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Выбрать месяц и год")
                monthArrow(-1, label: "Предыдущий месяц", symbol: "chevron.left")
                monthArrow(1, label: "Следующий месяц", symbol: "chevron.right")
            }
            if choosingMonth {
                HStack(spacing: 0) {
                    Picker("Месяц", selection: $jumpMonth) {
                        ForEach(1...12, id: \.self) { value in
                            Text(calendar.monthSymbols[value - 1].localizedCapitalized).tag(value)
                        }
                    }
                    Picker("Год", selection: $jumpYear) {
                        ForEach(1900...2199, id: \.self) { Text(String($0)).tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .frame(height: 180).clipped()
                Button("Показать месяц") {
                    var components = DateComponents()
                    components.year = jumpYear; components.month = jumpMonth; components.day = 1; components.hour = 12
                    if let date = calendar.date(from: components) { month = date }
                    choosingMonth = false
                }
                .frame(minHeight: 44)
            } else {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date { dayButton(date) }
                        else { Color.clear.frame(height: 44).accessibilityHidden(true) }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    private func monthArrow(_ delta: Int, label: String, symbol: String) -> some View {
        Button {
            if let date = shiftedMonth(delta) { month = date }
        } label: {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
        .disabled(shiftedMonth(delta) == nil)
        .accessibilityLabel(label)
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selection)
        let marked = taskDays.contains(TaskPlannedDate.civilDateString(from: date, calendar: calendar))
        return Button {
            selection = date
            onSelect()
        } label: {
            VStack(spacing: 2) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.body.weight(selected ? .semibold : .regular))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.orbitAccent : .clear, in: Circle())
                Circle().fill(marked ? Color.orbitAccent : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "ru_RU"))) + (marked ? ", есть задачи" : ""))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
