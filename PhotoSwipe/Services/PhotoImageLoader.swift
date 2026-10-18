import Photos
import UIKit

@MainActor
final class PhotoImageLoader {
    private let manager = PHCachingImageManager()
    private var cachedIdentifiers: [String] = []
    private var cachedTargetSize: CGSize = .zero

    func request(
        _ asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFit,
        resultHandler: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = makeOptions(targetSize: targetSize, deliveryMode: .opportunistic)
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
        let size = targetSize == .zero ? PHImageManagerMaximumSize : targetSize
        guard identifiers != cachedIdentifiers || size != cachedTargetSize else { return }

        stopCaching()
        cachedIdentifiers = identifiers
        cachedTargetSize = size
        guard !assets.isEmpty else { return }

        manager.startCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFit,
            options: makeOptions(targetSize: size, deliveryMode: .opportunistic)
        )
    }

    func stopCaching() {
        manager.stopCachingImagesForAllAssets()
        cachedIdentifiers.removeAll()
        cachedTargetSize = .zero
    }

    func exportForSharing(_ asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = makeOptions(targetSize: PHImageManagerMaximumSize, deliveryMode: .highQualityFormat)
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

    private func makeOptions(
        targetSize: CGSize,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = targetSize == PHImageManagerMaximumSize ? .none : .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        return options
    }

    private static func fileExtension(for uti: String?) -> String {
        switch uti {
        case "public.png":
            return "png"
        case "public.heic":
            return "heic"
        default:
            return "jpg"
        }
    }
}
