import CoreLocation
import Foundation
import Photos

struct PhotoItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?
    let location: CLLocation?

    init(id: String, asset: PHAsset, creationDate: Date?, location: CLLocation?) {
        self.id = id
        self.asset = asset
        self.creationDate = creationDate
        self.location = location
    }

    init(asset: PHAsset, creationDate: Date? = nil, location: CLLocation? = nil) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = creationDate ?? asset.creationDate
        self.location = location ?? asset.location
    }

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

/// Metadata captured during the Photos fetch so later UI access does not demand-load original properties on the main queue.
struct PhotoSnapshot: Sendable {
    let id: String
    let creationDate: Date?
    let latitude: Double?
    let longitude: Double?

    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    init(asset: PHAsset, creationDate: Date) {
        self.id = asset.localIdentifier
        self.creationDate = creationDate
        if let location = asset.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        } else {
            latitude = nil
            longitude = nil
        }
    }
}
