import Photos
import UIKit

@MainActor
final class PhotoImageLoader {
    private let manager = PHCachingImageManager()
    private var cachedIdentifiers: [String] = []

    func request(
        _ asset: PHAsset,
        targetSize: CGSize,
        resultHandler: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
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
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        manager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCaching() {
        manager.stopCachingImagesForAllAssets()
        cachedIdentifiers.removeAll()
    }
}
