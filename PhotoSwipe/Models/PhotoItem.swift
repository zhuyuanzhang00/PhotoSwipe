import CoreLocation
import Foundation
import Photos

/// PHAsset is safe to read across threads for our fetch → UI handoff.
struct PhotoItem: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?
    let location: CLLocation?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct SwipeRecord {
    let item: PhotoItem
    let action: SwipeAction
}
