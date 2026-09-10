import Photos
import SwiftUI
import UIKit

struct PhotoImageView: View {
    let asset: PHAsset
    let loader: PhotoImageLoader

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .onAppear {
                start()
            }
            .onChange(of: asset.localIdentifier) {
                start()
            }
            .onDisappear {
                cancel()
            }
        }
    }

    private func start() {
        cancel()
        image = nil
        requestID = loader.request(
            asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit
        ) { loaded in
            if let loaded {
                image = loaded
            }
        }
    }

    private func cancel() {
        if let requestID {
            loader.cancel(requestID)
            self.requestID = nil
        }
    }
}

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let loader: PhotoImageLoader

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color(white: 0.12)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .onAppear {
                let side = 240 * displayScale
                requestID = loader.request(
                    asset,
                    targetSize: CGSize(width: side, height: side),
                    contentMode: .aspectFill
                ) { loaded in
                    if let loaded {
                        image = loaded
                    }
                }
            }
            .onDisappear {
                if let requestID {
                    loader.cancel(requestID)
                }
            }
    }
}
