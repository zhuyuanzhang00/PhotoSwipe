import Photos
import UIKit

@MainActor
final class PhotoImageLoader {
    private let manager = PHCachingImageManager()
    private var cachedIdentifiers: [String] = []

    func request(
        _ asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFit,
        resultHandler: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = targetSize == PHImageManagerMaximumSize ? .none : .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current

        return manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { image, _ in
            Task { @MainActor in
                resultHandler(image)
            }
        }
    }

    func cancel(_ requestID: PHImageRequestID) {
        manager.cancelImageRequest(requestID)
    }

    func cacheCurrentAndNext(_ items: [PhotoItem], targetSize: CGSize) {
        let assets = items.map(\.asset)
        let identifiers = assets.map(\.localIdentifier)
        guard identifiers != cachedIdentifiers else { return }

        stopCaching()
        cachedIdentifiers = identifiers
        guard !assets.isEmpty else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true
        options.version = .current

        manager.startCachingImages(
            for: assets,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        )
    }

    func stopCaching() {
        manager.stopCachingImagesForAllAssets()
        cachedIdentifiers.removeAll()
    }

    func exportForSharing(_ asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.version = .current

            var resumed = false
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                guard !resumed else { return }
                resumed = true

                guard !cancelled, let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let ext = Self.fileExtension(for: uti)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("PhotoSwipe-\(UUID().uuidString).\(ext)")
                do {
                    try data.write(to: url, options: .atomic)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func fileExtension(for uti: String?) -> String {
        switch uti {
        case "public.png", "public.heic":
            return uti == "public.png" ? "png" : "heic"
        default:
            return "jpg"
        }
    }
}
