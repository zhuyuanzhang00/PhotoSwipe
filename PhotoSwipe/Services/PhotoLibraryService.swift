import CoreLocation
import Foundation
import MapKit
import Photos
import UIKit

enum PhotoLibraryService {
    static func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func isAuthorized(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// Local identifiers for images whose creation date matches month-day, oldest first.
    nonisolated static func fetchPhotoIdentifiers(month: Int, day: Int) -> [String] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var matches: [String] = []
        let calendar = Calendar.current

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let parts = calendar.dateComponents([.month, .day], from: date)
            if parts.month == month, parts.day == day {
                matches.append(asset.localIdentifier)
            }
        }

        return matches
    }

    static func photos(for identifiers: [String]) -> [PhotoItem] {
        guard !identifiers.isEmpty else { return [] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetsByID: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = asset
        }

        return identifiers.compactMap { identifier in
            guard let asset = assetsByID[identifier] else { return nil }
            return PhotoItem(asset: asset)
        }
    }

    static func fileSize(of asset: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: asset).reduce(into: Int64(0)) { total, resource in
            let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
            total += size
        }
    }

    static func formattedByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func moveToTrash(_ items: [PhotoItem]) async throws {
        guard !items.isEmpty else { return }
        let assets = items.map(\.asset) as NSArray
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}

final class LocationNamer {
    static let shared = LocationNamer()

    private var cache: [String: String] = [:]

    func name(for location: CLLocation?) async -> String {
        guard let location else { return "Location unavailable" }

        let key = String(format: "%.5f,%.5f", location.coordinate.latitude, location.coordinate.longitude)
        if let cached = cache[key] {
            return cached
        }

        guard let request = MKReverseGeocodingRequest(location: location) else {
            return "Location unavailable"
        }

        do {
            let mapItems = try await request.mapItems
            let formatted = Self.format(mapItems.first) ?? "Location unavailable"
            cache[key] = formatted
            return formatted
        } catch {
            return "Location unavailable"
        }
    }

    private static func format(_ mapItem: MKMapItem?) -> String? {
        guard let mapItem else { return nil }

        if let city = mapItem.addressRepresentations?.cityName,
           let region = mapItem.addressRepresentations?.regionName,
           !region.isEmpty {
            return "\(city), \(region)"
        }
        if let city = mapItem.addressRepresentations?.cityName {
            return city
        }
        if let short = mapItem.address?.shortAddress, !short.isEmpty {
            return short
        }
        if let name = mapItem.name, !name.isEmpty {
            return name
        }
        return mapItem.address?.fullAddress
    }
}

enum PhotoDateFormat {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy • h:mm a"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    static func timestamp(from date: Date?) -> String {
        guard let date else { return "Date unavailable" }
        return timestamp.string(from: date)
    }

    static func monthDayTitle(from date: Date) -> String {
        monthDay.string(from: date)
    }
}
