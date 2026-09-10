import CoreLocation
import Foundation
import Photos

struct PhotoItem: Identifiable, Hashable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }
    var creationDate: Date? { asset.creationDate }
    var location: CLLocation? { asset.location }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}
