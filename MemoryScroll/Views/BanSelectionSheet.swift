import SwiftUI

/// Sheet that shows every photo in the current strip and lets the user
/// select which ones to ban from future generations.
struct BanSelectionSheet: View {
    @ObservedObject var vm: ImageScrollViewModel
    @ObservedObject private var bannedStore = BannedPhotosStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<String> = []

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.photos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        Text("Select photos to exclude from all future scrolls.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(vm.photos) { photo in
                                    BanCell(
                                        photo: photo,
                                        isSelected: selectedIDs.contains(photo.id),
                                        isAlreadyBanned: bannedStore.bannedIDs.contains(photo.id)
                                    ) { toggleSelection(photo.id) }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
            }
            .navigationTitle("Ban Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        bannedStore.ban(selectedIDs)
                        dismiss()
                    } label: {
                        Text(selectedIDs.isEmpty
                            ? NSLocalizedString("Ban", comment: "")
                            : String(format: NSLocalizedString("ban_count", comment: ""), selectedIDs.count))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(selectedIDs.isEmpty ? .gray : .red)
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.minus")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text("No photos in current scroll")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

// MARK: - Cell

private struct BanCell: View {
    let photo: ScrollPhoto
    let isSelected: Bool
    let isAlreadyBanned: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                        .opacity(isAlreadyBanned || isSelected ? 0.35 : 1.0)

                    if isAlreadyBanned {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.red)
                            .shadow(radius: 4)
                    } else if isSelected {
                        Color.red.opacity(0.15)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.red)
                            .shadow(radius: 4)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Color.red.opacity(0.8) : Color.clear, lineWidth: 2)
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyBanned)
    }
}
