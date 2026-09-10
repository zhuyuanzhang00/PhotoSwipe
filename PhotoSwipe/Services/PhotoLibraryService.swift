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

    nonisolated static func makeFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]
        options.wantsIncrementalChangeDetails = false
        prefetchOriginalMetadata(on: options)
        return options
    }

    /// Prefetch original metadata (location, dates) so PHAsset does not fetch it on demand on the main queue.
    nonisolated static func prefetchOriginalMetadata(on options: PHFetchOptions) {
        if let propertySet = NSClassFromString("PHAssetOriginalMetadataProperties"),
           options.responds(to: NSSelectorFromString("setFetchPropertySets:")) {
            options.setValue([propertySet], forKey: "fetchPropertySets")
        }

        if options.responds(to: NSSelectorFromString("setPrefetchAssetExtendedMetadata:")) {
            options.setValue(true, forKey: "prefetchAssetExtendedMetadata")
        }
    }

    /// Photos whose creation date matches month-day, oldest first, with metadata snapshotted during fetch.
    nonisolated static func fetchOnThisDay(month: Int, day: Int) -> [PhotoSnapshot] {
        let options = makeFetchOptions()
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var matches: [PhotoSnapshot] = []
        let calendar = Calendar.current

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let parts = calendar.dateComponents([.month, .day], from: date)
            if parts.month == month, parts.day == day {
                matches.append(PhotoSnapshot(asset: asset, creationDate: date))
            }
        }

        return matches
    }

    static func photos(from snapshots: [PhotoSnapshot]) -> [PhotoItem] {
        guard !snapshots.isEmpty else { return [] }

        let identifiers = snapshots.map(\.id)
        let options = makeFetchOptions()
        options.predicate = nil
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
        var assetsByID: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = asset
        }

        return snapshots.compactMap { snapshot in
            guard let asset = assetsByID[snapshot.id] else { return nil }
            return PhotoItem(
                id: snapshot.id,
                asset: asset,
                creationDate: snapshot.creationDate,
                location: snapshot.location
            )
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

    static func monthDayKey(from date: Date) -> String {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", parts.month ?? 1, parts.day ?? 1)
    }
}
