import Foundation
import Photos
import SwiftUI

enum PermissionState {
    case unknown
    case authorized
    case denied
}

enum CurationPhase: Equatable {
    case loading
    case browsing
    case confirming
    case finished
}

enum SwipeAction {
    case keep
    case delete
}

@Observable
@MainActor
final class CurationViewModel {
    var permission: PermissionState = .unknown
    var phase: CurationPhase = .loading
    var selectedDate: Date = Date()
    var queue: [PhotoItem] = []
    var originalQueue: [PhotoItem] = []
    var selections: [String: PhotoItem] = [:]
    var toastMessage: String?
    var isDeleting = false
    var didCompleteReview = false
    var deleteError: String?
    var completedMonthDays: Set<String> = []

    let imageLoader = PhotoImageLoader()
    private let completedDaysBackend = CompletedDaysBackend.shared
    private var cacheTargetSize = CGSize(width: 1200, height: 2600)
    private var history: [SwipeRecord] = []

    var currentPhoto: PhotoItem? { queue.first }
    var nextPhoto: PhotoItem? {
        guard queue.count > 1 else { return nil }
        return queue[1]
    }

    var canSwipe: Bool {
        phase == .browsing && currentPhoto != nil
    }

    var canUndo: Bool {
        !history.isEmpty && !isDeleting && phase != .loading
    }

    var progressText: String {
        let total = originalQueue.count
        guard total > 0 else { return "0 of 0 photos" }
        let remaining = queue.count
        let current = remaining == 0 ? total : total - remaining + 1
        return "\(current) of \(total) photos"
    }

    var photosToDelete: [PhotoItem] {
        selections.values.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    var selectedDayTitle: String {
        PhotoDateFormat.monthDayTitle(from: selectedDate)
    }

    func start() async {
        completedMonthDays = completedDaysBackend.completedMonthDays
        let status = PhotoLibraryService.authorizationStatus()
        if status == .notDetermined {
            let updated = await PhotoLibraryService.requestAuthorization()
            handleAuthorization(updated)
        } else {
            handleAuthorization(status)
        }
    }

    func handleAuthorization(_ status: PHAuthorizationStatus) {
        if PhotoLibraryService.isAuthorized(status) {
            permission = .authorized
            Task { await loadFeed() }
        } else {
            permission = .denied
        }
    }

    func loadFeed() async {
        phase = .loading
        queue = []
        originalQueue = []
        selections = [:]
        history = []
        didCompleteReview = false
        deleteError = nil
        imageLoader.stopCaching()
        await Task.yield()

        let parts = Calendar.current.dateComponents([.month, .day], from: selectedDate)
        let month = parts.month ?? 1
        let day = parts.day ?? 1

        let snapshots = await Task.detached(priority: .userInitiated) {
            PhotoLibraryService.fetchOnThisDay(month: month, day: day)
        }.value
        let photos = PhotoLibraryService.photos(from: snapshots)

        originalQueue = photos
        queue = photos

        if photos.isEmpty {
            phase = .finished
        } else {
            phase = .browsing
            updateImageCache()
        }
    }

    func apply(_ action: SwipeAction) {
        guard canSwipe, let photo = currentPhoto else { return }

        if action == .delete {
            selections[photo.id] = photo
        }

        history.append(SwipeRecord(item: photo, action: action))
        queue.removeFirst()
        updateImageCache()

        if queue.isEmpty {
            finishQueue()
        }
    }

    func cancelConfirmation() {
        selections.removeAll()
        history.removeAll()
        queue = originalQueue
        deleteError = nil
        phase = originalQueue.isEmpty ? .finished : .browsing
        updateImageCache()
    }

    func undoLast() {
        guard canUndo, let record = history.popLast() else { return }

        if record.action == .delete {
            selections.removeValue(forKey: record.item.id)
        }

        if queue.first?.id != record.item.id {
            queue.insert(record.item, at: 0)
        }

        deleteError = nil
        didCompleteReview = false
        unmarkSelectedDayCompleted()
        phase = .browsing
        updateImageCache()
    }

    func confirmDeletion() async {
        let doomed = photosToDelete
        guard !doomed.isEmpty else {
            phase = .finished
            return
        }

        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }

        let bytes = doomed.reduce(Int64(0)) { $0 + PhotoLibraryService.fileSize(of: $1.asset) }

        do {
            try await PhotoLibraryService.moveToTrash(doomed)
            let count = doomed.count
            let photoWord = count == 1 ? "photo" : "photos"
            if bytes > 0 {
                let freed = PhotoLibraryService.formattedByteCount(bytes)
                showToast("\(count) \(photoWord) deleted • \(freed) freed")
            } else {
                showToast("\(count) \(photoWord) deleted")
            }

            selections.removeAll()
            queue = []
            imageLoader.stopCaching()
            markSelectedDayCompleted()
            didCompleteReview = true
            phase = .finished
        } catch {
            deleteError = "Couldn't move photos to Trash. Try again."
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        Task { await loadFeed() }
    }

    func shareCurrentPhoto() async -> SharePayload? {
        guard let photo = currentPhoto else { return nil }
        guard let url = await imageLoader.exportForSharing(photo.asset) else { return nil }
        return SharePayload(items: [url])
    }

    func updateCacheTarget(size: CGSize, scale: CGFloat) {
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard pixelSize != cacheTargetSize else { return }
        cacheTargetSize = pixelSize
        updateImageCache()
    }

    private func finishQueue() {
        didCompleteReview = true
        if selections.isEmpty {
            markSelectedDayCompleted()
            phase = .finished
        } else {
            phase = .confirming
        }
    }

    private func markSelectedDayCompleted() {
        completedDaysBackend.markCompleted(selectedDate)
        completedMonthDays = completedDaysBackend.completedMonthDays
    }

    private func unmarkSelectedDayCompleted() {
        completedDaysBackend.unmark(selectedDate)
        completedMonthDays = completedDaysBackend.completedMonthDays
    }

    private func updateImageCache() {
        let upcoming = Array(queue.prefix(2))
        imageLoader.cacheCurrentAndNext(upcoming, targetSize: cacheTargetSize)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
