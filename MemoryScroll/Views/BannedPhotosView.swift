import SwiftUI
import Photos

/// Displays all banned photos as a thumbnail grid and lets users unban them.
/// Mirrors the multi-select pattern from HistoryView.
struct BannedPhotosView: View {
    @ObservedObject private var store = BannedPhotosStore.shared

    @State private var thumbnails: [BannedThumbnail] = []
    @State private var isLoading = false
    @State private var selectedIDs: Set<String> = []
    @State private var isEditing = false
    @State private var showClearConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if thumbnails.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    toolbar
                    photoGrid
                }
            }
        }
        .navigationTitle("Banned Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            String(format: NSLocalizedString("unban_all_confirm", comment: ""), store.count),
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Unban All", role: .destructive) {
                store.clearAll()
                thumbnails.removeAll()
                isEditing = false
                selectedIDs.removeAll()
            }
        }
        .task { await loadThumbnails() }
        // Reload if the store changes from outside (e.g. BanSelectionSheet)
        .onChange(of: store.bannedIDs) { _ in
            Task { await loadThumbnails() }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text(thumbnails.count == 1
                ? String(format: NSLocalizedString("banned_count_singular", comment: ""), thumbnails.count)
                : String(format: NSLocalizedString("banned_count_plural",   comment: ""), thumbnails.count))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            if isEditing {
                Button(String(format: NSLocalizedString("unban_count", comment: ""), selectedIDs.count)) {
                    withAnimation {
                        store.unban(selectedIDs)
                        selectedIDs.removeAll()
                        if store.bannedIDs.isEmpty { isEditing = false }
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedIDs.isEmpty ? .gray : .cyan)
                .disabled(selectedIDs.isEmpty)

                Button("Done") {
                    isEditing = false
                    selectedIDs.removeAll()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 12)
            } else {
                Button("Select") { isEditing = true }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Button("Unban All") { showClearConfirm = true }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(thumbnails) { thumb in
                    BannedThumbnailCell(
                        thumbnail: thumb,
                        isEditing: isEditing,
                        isSelected: selectedIDs.contains(thumb.id)
                    ) { toggleSelection(thumb.id) }
                }
            }
            .padding(4)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text("No Banned Photos")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text("Photos you ban from the strip will appear here.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnails() async {
        guard !store.bannedIDs.isEmpty else {
            thumbnails = []
            return
        }

        isLoading = true
        let ids = Array(store.bannedIDs)

        // Fetch available PHAssets for the stored IDs
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assetMap: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assetMap[asset.localIdentifier] = asset
        }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        var result: [BannedThumbnail] = []

        for id in ids {
            if let asset = assetMap[id] {
                let image = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
                    manager.requestImage(
                        for: asset,
                        targetSize: CGSize(width: 200, height: 200),
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        if !isDegraded { cont.resume(returning: image) }
                    }
                }
                result.append(BannedThumbnail(id: id, image: image))
            } else {
                // Asset was deleted from library — still show a placeholder so the
                // user can choose to clean it up.
                result.append(BannedThumbnail(id: id, image: nil))
            }
        }

        thumbnails = result
        isLoading = false
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

// MARK: - Data model

struct BannedThumbnail: Identifiable {
    let id: String       // PHAsset localIdentifier
    let image: UIImage?  // nil when asset no longer exists in the library
}

// MARK: - Cell

private struct BannedThumbnailCell: View {
    let thumbnail: BannedThumbnail
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    // Photo or placeholder
                    if let image = thumbnail.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                            .opacity(isEditing && isSelected ? 0.5 : 1.0)
                    } else {
                        // Deleted-from-library placeholder
                        ZStack {
                            Color.white.opacity(0.06)
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(width: geo.size.width, height: geo.size.width)
                    }

                    // Edit mode selection indicator
                    if isEditing {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? .cyan : .white.opacity(0.5))
                            .padding(5)
                            .shadow(radius: 2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isEditing && isSelected ? Color.cyan.opacity(0.8) : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}
