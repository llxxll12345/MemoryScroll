//
//  HistoryDetailView.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/12/26.
//

import SwiftUI

/// Full-screen navigation destination for a single history item.
/// Using a pushed view (instead of a sheet) means Share and CropAdjust sheets
/// can be presented without the "sheet on sheet" limitation.
struct HistoryDetailView: View {
    let itemID: UUID
    @ObservedObject var vm: ImageScrollViewModel

    @State private var showShareSheet = false
    @State private var showCropSheet = false
    @Environment(\.dismiss) private var dismiss

    /// Always read the live item so crop-adjusted images are reflected immediately.
    private var item: HistoryItem? {
        vm.history.first { $0.id == itemID }
    }

    /// Crop is only meaningful for the current strip.
    private var canCrop: Bool { itemID == vm.currentHistoryID }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let item {
                VStack(spacing: 16) {
                    ScrollStripView(image: item.image, orientation: item.orientation)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16)

                    // Info row
                    HStack(spacing: 16) {
                        Label("\(item.photoCount)", systemImage: "photo.stack")
                        Spacer()
                        Text("\(Int(item.image.size.width))×\(Int(item.image.size.height))")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 20)

                    // Action buttons
                    HStack(spacing: 12) {
                        actionButton(icon: "square.and.arrow.up", label: "Share") {
                            showShareSheet = true
                        }
                        actionButton(icon: "square.and.arrow.down", label: "Save") {
                            Task { await PhotoLibraryService.saveImageToAppAlbum(item.image) }
                        }
                        if canCrop {
                            actionButton(icon: "crop", label: "Crop") {
                                showCropSheet = true
                            }
                        }
                        actionButton(icon: "trash", label: "Delete", isDestructive: true) {
                            vm.deleteHistoryItem(item)
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            } else {
                // Item was deleted while viewing
                Text("Item no longer available")
                    .foregroundStyle(.white.opacity(0.4))
                    .onAppear { dismiss() }
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showShareSheet) {
            if let item { ShareSheet(items: [item.image]) }
        }
        .sheet(isPresented: $showCropSheet) {
            CropAdjustSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func actionButton(
        icon: String, label: LocalizedStringKey, isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isDestructive ? .red : .white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isDestructive ? Color.red.opacity(0.12) : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }
}
