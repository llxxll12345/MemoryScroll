import SwiftUI

// MARK: - HistoryView

/// Displays a grid of previously generated scroll images with multi-select delete.
struct HistoryView: View {
    @ObservedObject var vm: ImageScrollViewModel
    @State private var selection = Set<UUID>()
    @State private var isEditing = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vm.history.isEmpty {
                    emptyHistory
                } else {
                    historyGrid
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .navigationDestination(for: UUID.self) { itemID in
                HistoryDetailView(itemID: itemID, vm: vm)
            }
        }
    }

    // MARK: - Empty State

    private var emptyHistory: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text("No Scrolls Yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text("Generated scrolls will appear here.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private var historyGrid: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(vm.history.count == 1
                    ? String(format: NSLocalizedString("scroll_count_singular", comment: ""), vm.history.count)
                    : String(format: NSLocalizedString("scroll_count_plural",   comment: ""), vm.history.count))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                if isEditing {
                    Button(String(format: NSLocalizedString("delete_count", comment: ""), selection.count)) {
                        withAnimation {
                            vm.deleteHistoryItems(selection)
                            selection.removeAll()
                            if vm.history.isEmpty { isEditing = false }
                        }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .disabled(selection.isEmpty)

                    Button("Done") {
                        isEditing = false
                        selection.removeAll()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.leading, 12)
                } else {
                    Button("Select") { isEditing = true }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    if vm.history.count > 1 {
                        Button("Clear All") {
                            withAnimation { vm.clearHistory() }
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(.leading, 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.history) { item in
                        if isEditing {
                            // In edit mode: plain button for selection, no navigation
                            Button { toggleSelection(item.id) } label: {
                                HistoryCell(item: item, isEditing: true,
                                            isSelected: selection.contains(item.id))
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: item.id) {
                                HistoryCell(item: item, isEditing: false, isSelected: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) }
        else { selection.insert(id) }
    }
}

// MARK: - History Cell

struct HistoryCell: View {
    let item: HistoryItem
    let isEditing: Bool
    let isSelected: Bool

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    Image(uiImage: item.thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.white.opacity(0.04))
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 4) {
                    Text(String(format: NSLocalizedString("photos_count", comment: ""), item.photoCount))
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Text(timeAgo)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.4))
            }

            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.4))
                    .padding(8)
                    .transition(.scale)
            }
        }
    }
}

// MARK: - History Detail View

