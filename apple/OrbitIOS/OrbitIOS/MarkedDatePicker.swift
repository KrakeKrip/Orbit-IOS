import SwiftUI
import UIKit
import OrbitCore

/// A bounded month grid with one task-presence marker per planned civil day.
struct MarkedDatePicker: View {
    @Binding var selection: Date
    let taskDays: Set<String>
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            Text(selection.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "ru_RU"))))
                .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать дату")
        .accessibilityValue(RussianDateCaption.label(TaskPlannedDate.civilDateString(from: selection)))
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
struct MarkedMonthCalendar: View {
    @Environment(\.orbitAppearance) private var appearance
    @Binding var selection: Date
    let taskDays: Set<String>
    let onSelect: () -> Void
    var pinsHeader = false
    var allowsCollapse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
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

    init(selection: Binding<Date>, taskDays: Set<String>, pinsHeader: Bool = false, allowsCollapse: Bool = false, onSelect: @escaping () -> Void) {
        _selection = selection
        self.taskDays = taskDays
        self.onSelect = onSelect
        self.pinsHeader = pinsHeader
        self.allowsCollapse = allowsCollapse
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
        Group {
            if pinsHeader {
                LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                    Section { monthContent } header: {
                        monthHeader.orbitHeaderSurface().zIndex(1)
                    }
                }
            } else {
                VStack(spacing: 8) { monthHeader; monthContent }
            }
        }
        .onChange(of: selection) { _, date in
            month = calendar.dateInterval(of: .month, for: date)!.start
        }
        .buttonStyle(.plain)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    @ViewBuilder private var monthContent: some View {
        if isExpanded {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday).font(.caption.weight(.medium)).foregroundStyle(appearance.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date { dayButton(date) }
                    else { Color.clear.frame(height: 44).accessibilityHidden(true) }
                }
            }
            .contentShape(Rectangle())
            .background(OrbitMonthSwipeRecognizer(move: moveMonth).allowsHitTesting(false))
            .transition(.opacity)
        }
        if allowsCollapse {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Свернуть календарь" : "Развернуть календарь")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline).foregroundStyle(Color.orbitAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("month-calendar-collapse")
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button {
                jumpYear = calendar.component(.year, from: month)
                jumpMonth = calendar.component(.month, from: month)
                choosingMonth = true
            } label: {
                HStack(spacing: 4) {
                    Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))))
                        .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.orbitAccent)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Выбрать месяц и год")
            .accessibilityValue(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))))
            .popover(isPresented: $choosingMonth) {
                monthPicker
                    .frame(width: 300)
                    .padding(12)
                    .presentationBackground(appearance.canvas)
                    .presentationCompactAdaptation(.popover)
            }
            monthArrow(-1, label: "Предыдущий месяц", symbol: "chevron.left")
            monthArrow(1, label: "Следующий месяц", symbol: "chevron.right")
        }
    }

    private var monthPicker: some View {
        VStack(spacing: 4) {
            HStack {
                Button("Отмена") { choosingMonth = false }
                Spacer()
                Button("Показать") {
                    var components = DateComponents()
                    components.year = jumpYear; components.month = jumpMonth
                    components.day = 1; components.hour = 12
                    if let date = calendar.date(from: components) { month = date }
                    choosingMonth = false
                }.fontWeight(.semibold)
            }
            .frame(minHeight: 44)
            .foregroundStyle(Color.orbitAccent)
            HStack(spacing: 0) {
                Picker("Месяц", selection: $jumpMonth) {
                    ForEach(1...12, id: \.self) { value in
                        Text(calendar.standaloneMonthSymbols[value - 1].localizedCapitalized).tag(value)
                    }
                }
                .frame(width: 175)
                Picker("Год", selection: $jumpYear) {
                    ForEach(1900...2199, id: \.self) { Text(String($0)).tag($0) }
                }
                .frame(width: 125)
            }
            .pickerStyle(.wheel)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .frame(height: 180).clipped()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func moveMonth(_ delta: Int) {
        guard let date = shiftedMonth(delta) else { return }
        // Keep the drag/vertical deceleration independent of grid transitions.
        month = date
        OrbitHaptics.selection()
    }

    private func monthArrow(_ delta: Int, label: String, symbol: String) -> some View {
        Button { moveMonth(delta) } label: {
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
                    .frame(minWidth: 34, minHeight: 34)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.orbitAccentFill : .clear, in: Circle())
                    .overlay(Circle().stroke(calendar.isDateInToday(date) && !selected ? Color.primary : .clear, lineWidth: 1))
                Circle().fill(marked ? Color.orbitAccent : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "ru_RU"))) + (calendar.isDateInToday(date) ? ", сегодня" : "") + (marked ? ", есть задачи" : ""))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Decide direction before a swipe begins. A SwiftUI DragGesture on the grid
/// can claim vertical pans even when its onEnded handler ignores that axis.
private struct OrbitMonthSwipeRecognizer: UIViewRepresentable {
    let move: (Int) -> Void
    final class ProbeView: UIView {
        var resolve: (() -> Void)?
        override func layoutSubviews() { super.layoutSubviews(); resolve?() }
        override func didMoveToWindow() { super.didMoveToWindow(); resolve?() }
    }
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func updateUIView(_ view: ProbeView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.marker = view
        let coordinator = context.coordinator
        view.resolve = { [weak view, weak coordinator] in
            DispatchQueue.main.async { [weak view, weak coordinator] in
                guard let view, let coordinator, view.window != nil else { return }
                var ancestor = view.superview
                while let parent = ancestor {
                    if parent is UIScrollView { coordinator.attach(parent); return }
                    ancestor = parent.superview
                }
                if let host = view.superview { coordinator.attach(host) }
            }
        }
        view.resolve?()
    }
    static func dismantleUIView(_ view: ProbeView, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: OrbitMonthSwipeRecognizer
        weak var marker: UIView?
        weak var host: UIView?
        var start = CGPoint.zero
        var furthest = CGPoint.zero
        lazy var pan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handle))
            recognizer.delegate = self
            recognizer.maximumNumberOfTouches = 1
            return recognizer
        }()
        init(parent: OrbitMonthSwipeRecognizer) { self.parent = parent }
        func attach(_ host: UIView) {
            guard self.host !== host else { return }
            detach()
            self.host = host
            host.addGestureRecognizer(pan)
        }
        func detach() { host?.removeGestureRecognizer(pan); host = nil }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let marker, marker.window != nil else { return false }
            start = touch.location(in: nil)
            furthest = .zero
            let inside = marker.convert(marker.bounds, to: nil).contains(start)
            return inside
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let velocity = pan.velocity(in: host)
            return abs(velocity.x) > abs(velocity.y) * 1.6
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        @objc private func handle(_ recognizer: UIPanGestureRecognizer) {
            let point = recognizer.location(in: nil)
            let delta = CGPoint(x: point.x - start.x, y: point.y - start.y)
            if abs(delta.x) > abs(furthest.x) { furthest = delta }
            guard recognizer.state == .ended else { return }
            guard abs(furthest.x) > 65, abs(furthest.x) > abs(furthest.y) * 1.6 else { return }
            parent.move(furthest.x < 0 ? 1 : -1)
        }
    }
}
