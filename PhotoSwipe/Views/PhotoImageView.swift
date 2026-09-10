import Photos
import SwiftUI
import UIKit

struct PhotoImageView: View {
    let asset: PHAsset
    let loader: PhotoImageLoader

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .onAppear {
                start(size: proxy.size)
            }
            .onChange(of: asset.localIdentifier) {
                start(size: proxy.size)
            }
            .onDisappear {
                cancel()
            }
        }
    }

    private func start(size: CGSize) {
        cancel()
        image = nil
        let target = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        requestID = loader.request(asset, targetSize: target) { loaded in
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
                requestID = loader.request(asset, targetSize: CGSize(width: side, height: side)) { loaded in
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
