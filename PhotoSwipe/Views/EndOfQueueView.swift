import SwiftUI

struct EndOfQueueView: View {
    @Bindable var viewModel: CurationViewModel
    var onPickDay: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.9))

            Text("End of Queue")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)

            Text(emptyCopy)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onPickDay) {
                Label("Pick another day", systemImage: "calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .padding(.horizontal, 40)
            .padding(.top, 8)

            if viewModel.canUndo {
                Button {
                    viewModel.undoLast()
                } label: {
                    Label("Undo last photo", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var emptyCopy: String {
        if viewModel.didCompleteReview {
            return "You've reviewed every photo from \(viewModel.selectedDayTitle). Pick another day to keep going."
        }
        return "No photos from \(viewModel.selectedDayTitle) across the years. Choose another day to keep curating."
    }
}

struct DayPickerSheet: View {
    @Bindable var viewModel: CurationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Day",
                    selection: $draftDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.white)
                .padding(.horizontal, 8)

                Text("PhotoSwipe matches month and day across every year in your library.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 8)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Pick a Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        viewModel.selectDate(draftDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draftDate = viewModel.selectedDate
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        .padding(.top, 8)
    }
}
