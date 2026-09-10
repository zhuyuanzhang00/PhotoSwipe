import SwiftUI
import UIKit

struct SwipeDeckView: View {
    @Bindable var viewModel: CurationViewModel
    var onPickDay: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var dragOffset: CGSize = .zero
    @State private var isFlinging = false
    @State private var sharePayload: SharePayload?
    @State private var isPreparingShare = false

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                if let next = viewModel.nextPhoto {
                    PhotoCardView(
                        item: next,
                        progressText: viewModel.progressText,
                        loader: viewModel.imageLoader,
                        dragOffset: .zero,
                        showsChrome: false,
                        canUndo: false,
                        isSharing: false,
                        onDelete: {},
                        onUndo: {},
                        onShare: {}
                    )
                    .id(next.id)
                    .scaleEffect(0.96)
                    .opacity(0.55)
                    .padding(cardPadding)
                    .allowsHitTesting(false)
                }

                if let current = viewModel.currentPhoto {
                    PhotoCardView(
                        item: current,
                        progressText: viewModel.progressText,
                        loader: viewModel.imageLoader,
                        dragOffset: dragOffset,
                        showsChrome: true,
                        canUndo: viewModel.canUndo,
                        isSharing: isPreparingShare,
                        onDelete: { fling(.delete, width: proxy.size.width) },
                        onUndo: { undoLast() },
                        onShare: { shareCurrent() }
                    )
                    .id(current.id)
                    .padding(cardPadding)
                    .gesture(dragGesture(size: proxy.size))
                }
            }
            .safeAreaInset(edge: .top) {
                deckHeader
            }
            .onAppear {
                viewModel.updateCacheTarget(size: proxy.size, scale: displayScale)
            }
            .onChange(of: proxy.size) {
                viewModel.updateCacheTarget(size: proxy.size, scale: displayScale)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
        }
    }

    private var cardPadding: EdgeInsets {
        EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10)
    }

    private var deckHeader: some View {
        HStack {
            Button(action: onPickDay) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On This Day")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.selectedDayTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pick a day, currently \(viewModel.selectedDayTitle)")

            if viewModel.canUndo {
                Button(action: { undoLast() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Undo last swipe")
                .padding(.trailing, 8)
            }

            Button(action: onPickDay) {
                Label("Pick a day", systemImage: "calendar")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Pick a day")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard viewModel.canSwipe, !isFlinging else { return }
                if hypot(value.translation.width, value.translation.height) < 12 { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard viewModel.canSwipe, !isFlinging else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                    return
                }

                let distance = hypot(value.translation.width, value.translation.height)
                if distance < 16 {
                    if isCenterTap(start: value.startLocation, in: size) {
                        undoLast()
                    }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                    return
                }

                let dx = value.predictedEndTranslation.width
                if dx < -swipeThreshold {
                    fling(.delete, width: size.width)
                } else if dx > swipeThreshold {
                    fling(.keep, width: size.width)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func isCenterTap(start: CGPoint, in size: CGSize) -> Bool {
        let dx = abs(start.x - size.width / 2)
        let dy = abs(start.y - size.height / 2)
        return dx < size.width * 0.28 && dy < size.height * 0.22
    }

    private func undoLast() {
        guard viewModel.canUndo, !isFlinging else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragOffset = .zero
            viewModel.undoLast()
        }
    }

    private func shareCurrent() {
        guard !isPreparingShare, !isFlinging else { return }
        isPreparingShare = true
        Task {
            sharePayload = await viewModel.shareCurrentPhoto()
            isPreparingShare = false
        }
    }

    private func fling(_ action: SwipeAction, width: CGFloat) {
        guard viewModel.canSwipe, !isFlinging else { return }
        isFlinging = true

        let direction: CGFloat = action == .delete ? -1 : 1
        let haptic: UIImpactFeedbackGenerator = action == .delete
            ? UIImpactFeedbackGenerator(style: .medium)
            : UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: direction * (width + 160), height: dragOffset.height)
        } completion: {
            viewModel.apply(action)
            dragOffset = .zero
            isFlinging = false
        }
    }
}
