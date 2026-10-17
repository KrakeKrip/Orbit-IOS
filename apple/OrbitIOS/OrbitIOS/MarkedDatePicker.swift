import SwiftUI
import UIKit
import OrbitCore

/// Native month calendar with one task-presence marker per planned civil day.
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
                // A finite proposal is essential for UIKit's calendar: a minimum
                // height lets it expand to the whole available popover height.
                .frame(width: 320, height: 360)
                .padding(8)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct MarkedMonthCalendar: UIViewRepresentable {
    @Binding var selection: Date
    let taskDays: Set<String>
    let onSelect: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        var calendar = Calendar.orbitCivil
        calendar.firstWeekday = 2
        view.calendar = calendar
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.locale = Locale(identifier: "ru_RU")
        view.timeZone = .current
        view.tintColor = UIColor(Color.orbitAccent)
        view.availableDateRange = DateInterval(
            start: TaskPlannedDate.date(fromCivilDateString: "1900-01-01")!,
            end: TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!)
        view.delegate = context.coordinator
        view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        let components = view.calendar.dateComponents([.year, .month, .day], from: selection)
        (view.selectionBehavior as? UICalendarSelectionSingleDate)?.setSelected(components, animated: false)
        view.setVisibleDateComponents(components, animated: false)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        // Honor SwiftUI's finite bounds instead of UIKit's unconstrained
        // intrinsic size, which can otherwise overflow the popover edges.
        CGSize(width: proposal.width ?? 320, height: proposal.height ?? 360)
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        let oldDays = context.coordinator.parent.taskDays
        context.coordinator.parent = self
        if oldDays != taskDays {
            let dates = oldDays.union(taskDays).compactMap { TaskPlannedDate.date(fromCivilDateString: $0) }
                .map { view.calendar.dateComponents([.year, .month, .day], from: $0) }
            view.reloadDecorations(forDateComponents: dates, animated: false)
        }
        let components = view.calendar.dateComponents([.year, .month, .day], from: selection)
        let behavior = view.selectionBehavior as? UICalendarSelectionSingleDate
        if behavior?.selectedDate != components {
            behavior?.setSelected(components, animated: false)
            view.setVisibleDateComponents(components, animated: false)
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: MarkedMonthCalendar
        init(_ parent: MarkedMonthCalendar) { self.parent = parent }
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = calendarView.calendar.date(from: dateComponents) else { return nil }
            let day = TaskPlannedDate.civilDateString(from: date, calendar: calendarView.calendar)
            return parent.taskDays.contains(day) ? .default(color: UIColor(Color.orbitAccent), size: .small) : nil
        }
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let components = dateComponents, let date = Calendar.orbitCivil.date(from: components) else { return }
            parent.selection = date
            parent.onSelect()
        }
    }
}
