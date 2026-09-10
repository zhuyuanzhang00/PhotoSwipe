import SwiftUI

struct ConfirmationView: View {
    @Bindable var viewModel: CurationViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(headline)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("These photos will be moved to Recently Deleted. You can recover them from the Photos app for 30 days.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))

                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(viewModel.photosToDelete) { item in
                                PhotoThumbnailView(asset: item.asset, loader: viewModel.imageLoader)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                }

                if let deleteError = viewModel.deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await viewModel.confirmDeletion() }
                    } label: {
                        Group {
                            if viewModel.isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Move to Trash")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isDeleting)

                    Button("Cancel") {
                        viewModel.cancelConfirmation()
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .disabled(viewModel.isDeleting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 8)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var headline: String {
        let count = viewModel.photosToDelete.count
        let word = count == 1 ? "photo" : "photos"
        return "\(count) \(word) marked for deletion"
    }
}
