import CoreLocation
import Foundation
import MapKit
import Photos

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

    /// Photos whose creation date matches month-day, oldest first.
    /// Built in one pass so we do not re-fetch assets by identifier afterward.
    nonisolated static func fetchOnThisDay(month: Int, day: Int) -> [PhotoItem] {
        let options = makeFetchOptions()
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var matches: [PhotoItem] = []
        let calendar = Calendar.current

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let parts = calendar.dateComponents([.month, .day], from: date)
            guard parts.month == month, parts.day == day else { return }
            matches.append(
                PhotoItem(
                    id: asset.localIdentifier,
                    asset: asset,
                    creationDate: date,
                    location: asset.location
                )
            )
        }

        return matches
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

    nonisolated private static func makeFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]
        options.wantsIncrementalChangeDetails = false
        prefetchOriginalMetadata(on: options)
        return options
    }

    /// Prefetch original metadata so later UI access does not demand-load on the main queue.
    nonisolated private static func prefetchOriginalMetadata(on options: PHFetchOptions) {
        if let propertySet = NSClassFromString("PHAssetOriginalMetadataProperties"),
           options.responds(to: NSSelectorFromString("setFetchPropertySets:")) {
            options.setValue([propertySet], forKey: "fetchPropertySets")
        }

        if options.responds(to: NSSelectorFromString("setPrefetchAssetExtendedMetadata:")) {
            options.setValue(true, forKey: "prefetchAssetExtendedMetadata")
        }
    }
}

actor LocationNamer {
    static let shared = LocationNamer()

    private var cache: [String: String] = [:]

    func name(for location: CLLocation?) async -> String {
        guard let location else { return "No location" }

        let key = String(format: "%.5f,%.5f", location.coordinate.latitude, location.coordinate.longitude)
        if let cached = cache[key] {
            return cached
        }

        guard let request = MKReverseGeocodingRequest(location: location) else {
            return "Couldn't resolve location"
        }

        do {
            let mapItems = try await request.mapItems
            guard let formatted = Self.format(mapItems.first) else {
                return "Couldn't resolve location"
            }
            cache[key] = formatted
            return formatted
        } catch {
            return "Couldn't resolve location"
        }
    }

    private static func format(_ mapItem: MKMapItem?) -> String? {
        guard let mapItem else { return nil }

        if let city = mapItem.addressRepresentations?.cityName,
           let region = mapItem.addressRepresentations?.regionName,
           !region.isEmpty {
            return "\(city), \(region)"
        }
        if let city = mapItem.addressRepresentations?.cityName, !city.isEmpty {
            return city
        }
        if let short = mapItem.address?.shortAddress, !short.isEmpty {
            return short
        }
        if let name = mapItem.name, !name.isEmpty {
            return name
        }
        if let full = mapItem.address?.fullAddress, !full.isEmpty {
            return full
        }
        return nil
    }
}

enum PhotoDateFormat {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMMM d, yyyy • h:mm a"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    static func timestamp(from date: Date?) -> String {
        guard let date else { return "Unknown date" }
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
