import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DecoratedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    var completedMonthDays: Set<String>

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, completedMonthDays: completedMonthDays)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        calendarView.delegate = context.coordinator
        calendarView.tintColor = .white
        calendarView.overrideUserInterfaceStyle = .dark
        calendarView.backgroundColor = .clear

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.setSelected(
            Calendar.current.dateComponents([.year, .month, .day], from: selectedDate),
            animated: false
        )
        calendarView.selectionBehavior = selection
        context.coordinator.selection = selection
        return calendarView
    }

    func updateUIView(_ calendarView: UICalendarView, context: Context) {
        context.coordinator.selectedDate = $selectedDate
        context.coordinator.completedMonthDays = completedMonthDays

        let visible = calendarView.visibleDateComponents
        let year = visible.year ?? Calendar.current.component(.year, from: selectedDate)
        let month = visible.month ?? Calendar.current.component(.month, from: selectedDate)
        let components = (1...31).map {
            DateComponents(calendar: Calendar.current, year: year, month: month, day: $0)
        }
        calendarView.reloadDecorations(forDateComponents: components, animated: false)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var selectedDate: Binding<Date>
        var completedMonthDays: Set<String>
        var selection: UICalendarSelectionSingleDate?

        init(selectedDate: Binding<Date>, completedMonthDays: Set<String>) {
            self.selectedDate = selectedDate
            self.completedMonthDays = completedMonthDays
        }

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            guard let month = dateComponents.month, let day = dateComponents.day else { return nil }
            let key = String(format: "%02d-%02d", month, day)
            guard completedMonthDays.contains(key) else { return nil }
            return .default(color: .systemRed, size: .large)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let date = dateComponents?.date else { return }
            selectedDate.wrappedValue = date
        }
    }
}
