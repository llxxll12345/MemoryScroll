//
//  LocationPickerSheet.swift
//  MemoryScroll
//

import SwiftUI

struct LocationPickerSheet: View {
    @ObservedObject var vm: ImageScrollViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [LocationOption] {
        guard !searchText.isEmpty else { return vm.availableLocations }
        return vm.availableLocations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingLocations {
                    loadingView
                } else if vm.availableLocations.isEmpty {
                    emptyView
                } else {
                    locationList
                }
            }
            .navigationTitle("Filter by Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !vm.selectedLocationNames.isEmpty {
                        Button("Clear") {
                            vm.selectedLocationNames.removeAll()
                        }
                        .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color.black)
        }
        .task { await vm.loadLocations() }
    }

    // MARK: - List

    private var locationList: some View {
        List {
            // "Any location" row — clears filter
            Button {
                vm.selectedLocationNames.removeAll()
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .frame(width: 28)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Any Location")
                        .foregroundStyle(.primary)
                    Spacer()
                    if vm.selectedLocationNames.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.white.opacity(0.06))

            ForEach(filtered) { option in
                locationRow(option)
            }

            // "Load More" row — only shown when not searching and more pages remain
            if searchText.isEmpty && (vm.hasMoreLocations || vm.isLoadingLocations) {
                HStack {
                    Spacer()
                    if vm.isLoadingLocations {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Button("Load More") {
                            Task { await vm.loadMoreLocations() }
                        }
                        .foregroundStyle(.cyan)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                }
                .listRowBackground(Color.white.opacity(0.04))
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search locations")
        .scrollContentBackground(.hidden)
    }

    private func locationRow(_ option: LocationOption) -> some View {
        let isSelected = vm.selectedLocationNames.contains(option.name)

        return Button {
            if isSelected {
                vm.selectedLocationNames.remove(option.name)
            } else {
                vm.selectedLocationNames.insert(option.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.3))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .foregroundStyle(.primary)
                        .font(.system(size: 15))
                    Text(option.count == 1
                        ? String(format: NSLocalizedString("location_photo_singular", comment: ""), option.count)
                        : String(format: NSLocalizedString("location_photo_plural",   comment: ""), option.count))
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.06)
        )
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white)
            Text("Scanning locations…")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text("No Location Data")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text("None of your photos have GPS data.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
