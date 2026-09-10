import SwiftUI

struct PhotoCardView: View {
    let item: PhotoItem
    let progressText: String
    let loader: PhotoImageLoader
    let dragOffset: CGSize
    let showsChrome: Bool
    let onDelete: () -> Void

    @State private var locationText = "Location unavailable"

    private var rotation: Double {
        Double(dragOffset.width / 18)
    }

    private var deleteOpacity: Double {
        min(max(-dragOffset.width / 110, 0), 1)
    }

    private var keepOpacity: Double {
        min(max(dragOffset.width / 110, 0), 1)
    }

    var body: some View {
        ZStack {
            PhotoImageView(asset: item.asset, loader: loader)

            LinearGradient(
                colors: [
                    .black.opacity(0.72),
                    .black.opacity(0.18),
                    .clear,
                    .black.opacity(0.35),
                    .black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            if showsChrome {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(PhotoDateFormat.timestamp(from: item.creationDate))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)

                            Text(locationText)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.84))
                                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                        }

                        Spacer(minLength: 12)

                        Text(progressText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.35), in: Capsule())
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.red.opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                        }
                        .accessibilityLabel("Mark photo for deletion")
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            stamp(text: "DELETE", color: .red, opacity: deleteOpacity, rotation: -18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)

            stamp(text: "KEEP", color: .green, opacity: keepOpacity, rotation: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .offset(dragOffset)
        .rotationEffect(.degrees(rotation))
        .task(id: item.id) {
            locationText = await LocationNamer.shared.name(for: item.location)
        }
    }

    private func stamp(text: String, color: Color, opacity: Double, rotation: Double) -> some View {
        Text(text)
            .font(.title.weight(.heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color, lineWidth: 4)
            )
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}
