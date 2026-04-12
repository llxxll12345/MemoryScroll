import SwiftUI

struct CategoryPickerSheet: View {
    @ObservedObject var vm: ImageScrollViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Photos will be filtered by category before being spread evenly across your time frame.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(PhotoCategory.allCases) { category in
                                CategoryCard(
                                    category: category,
                                    isSelected: vm.selectedCategory == category
                                ) {
                                    vm.selectedCategory = category
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Photo Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: PhotoCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                    .frame(height: 32)

                Text(category.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.65))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isSelected ? Color.white : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    CategoryPickerSheet(vm: ImageScrollViewModel())
}
