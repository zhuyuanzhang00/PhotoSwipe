import SwiftUI

struct ContentView: View {
    @State private var viewModel = CurationViewModel()
    @State private var showDayPicker = false

    var body: some View {
        Group {
            switch viewModel.permission {
            case .unknown:
                loadingView(message: "Requesting photo access…")
            case .denied:
                PermissionDeniedView()
            case .authorized:
                authorizedContent
            }
        }
        .task {
            await viewModel.start()
        }
        .overlay(alignment: .top) {
            if let toast = viewModel.toastMessage {
                ToastBanner(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.toastMessage)
        .sheet(isPresented: $showDayPicker) {
            DayPickerSheet(viewModel: viewModel)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        switch viewModel.phase {
        case .loading:
            loadingView(message: "Loading On This Day…")
        case .browsing:
            SwipeDeckView(viewModel: viewModel, onPickDay: { showDayPicker = true })
        case .confirming:
            ConfirmationView(viewModel: viewModel)
        case .finished:
            EndOfQueueView(viewModel: viewModel, onPickDay: { showDayPicker = true })
        }
    }

    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
