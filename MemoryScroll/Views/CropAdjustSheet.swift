//
//  CropAdjustSheet.swift
//  MemoryScroll
//

import SwiftUI

struct CropAdjustSheet: View {
    @ObservedObject var vm: ImageScrollViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(vm.photos) { photo in
                        CropPhotoCard(photo: photo, vm: vm)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.black)
            .navigationTitle("Adjust Crops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset All") {
                        vm.cropBounds = [:]
                        vm.recomposite()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        vm.persistCurrentHistoryImage()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Per-photo Card

private struct CropPhotoCard: View {
    let photo: ScrollPhoto
    @ObservedObject var vm: ImageScrollViewModel

    // Saved fractions at the start of each drag so translation is additive
    @State private var dragStartTop: CGFloat = 0
    @State private var dragStartBottom: CGFloat = 0

    private var bounds: CropBounds { vm.cropBounds[photo.id] ?? .zero }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text(photo.creationDate, style: .date)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if bounds != .zero {
                    Button("Reset") {
                        vm.cropBounds[photo.id] = .zero
                        vm.recomposite()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                }
            }

            // Image at full natural aspect ratio (no clipping)
            Image(uiImage: photo.image)
                .resizable()
                .aspectRatio(photo.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 360)
                .overlay(cropOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Overlay (handles + dim regions)

    private var cropOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let topPx = h * bounds.top
            let botPx = h * bounds.bottom

            ZStack(alignment: .top) {
                // Dimmed top region
                if topPx > 0 {
                    Color.black.opacity(0.6)
                        .frame(width: w, height: topPx)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                // Dimmed bottom region
                if botPx > 0 {
                    Color.black.opacity(0.6)
                        .frame(width: w, height: botPx)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                // Top handle — centered on the crop line
                handleBar
                    .frame(width: w)
                    .offset(y: max(0, topPx - 14))
                    .gesture(topGesture(totalHeight: h))

                // Bottom handle
                handleBar
                    .frame(width: w)
                    .offset(y: h - botPx - 14)
                    .gesture(bottomGesture(totalHeight: h))

                // Percentage badges (shown in the middle of the visible band)
                HStack {
                    if bounds.top > 0.01 {
                        badge(String(format: NSLocalizedString("top_crop_pct", comment: ""), Int(bounds.top * 100)))
                    }
                    Spacer()
                    if bounds.bottom > 0.01 {
                        badge(String(format: NSLocalizedString("bottom_crop_pct", comment: ""), Int(bounds.bottom * 100)))
                    }
                }
                .padding(8)
                .offset(y: topPx + (h - topPx - botPx) / 2 - 14)
            }
        }
    }

    // MARK: Gestures

    /// Drag gesture for the top handle. `translation.height` is always relative to
    /// the drag start, so we snapshot the fraction at gesture start via `dragStartTop`.
    private func topGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                // Snapshot on first meaningful movement
                if abs(value.startLocation.y - value.location.y) < 2 {
                    dragStartTop = bounds.top
                }
                var b = bounds
                b.top = dragStartTop + value.translation.height / totalHeight
                b.clamp()
                if b.top + b.bottom >= 0.95 { b.top = max(0, 0.94 - b.bottom) }
                vm.cropBounds[photo.id] = b
                // Overlay updates live; strip recomposites only on lift
            }
            .onEnded { _ in
                dragStartTop = bounds.top
                vm.recomposite()
            }
    }

    private func bottomGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if abs(value.startLocation.y - value.location.y) < 2 {
                    dragStartBottom = bounds.bottom
                }
                var b = bounds
                b.bottom = dragStartBottom - value.translation.height / totalHeight
                b.clamp()
                if b.top + b.bottom >= 0.95 { b.bottom = max(0, 0.94 - b.top) }
                vm.cropBounds[photo.id] = b
            }
            .onEnded { _ in
                dragStartBottom = bounds.bottom
                vm.recomposite()
            }
    }

    // MARK: Helpers

    private var handleBar: some View {
        HStack {
            Capsule()
                .frame(width: 30, height: 5)
                .foregroundStyle(.white)
        }
        .frame(height: 28)
        .background(Color.cyan.opacity(0.3))
        .overlay(Rectangle().frame(height: 1.5).foregroundStyle(Color.cyan), alignment: .center)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.65), in: Capsule())
    }
}
