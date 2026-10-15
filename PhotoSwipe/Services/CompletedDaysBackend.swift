import Foundation

/// Local persistence for completed On This Day month-days (MM-DD).
@Observable
final class CompletedDaysBackend {
    static let shared = CompletedDaysBackend()

    private(set) var completedMonthDays: Set<String> = []

    private let fileURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoSwipe", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("completed-days.json")
    }()

    private init() {
        load()
    }

    func markCompleted(_ date: Date) {
        let key = PhotoDateFormat.monthDayKey(from: date)
        guard completedMonthDays.insert(key).inserted else { return }
        save()
    }

    func unmark(_ date: Date) {
        let key = PhotoDateFormat.monthDayKey(from: date)
        guard completedMonthDays.remove(key) != nil else { return }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let keys = try? JSONDecoder().decode([String].self, from: data) else {
            completedMonthDays = []
            return
        }
        completedMonthDays = Set(keys)
    }

    private func save() {
        let keys = Array(completedMonthDays).sorted()
        guard let data = try? JSONEncoder().encode(keys) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
