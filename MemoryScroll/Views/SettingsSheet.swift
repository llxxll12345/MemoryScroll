import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var vm: ImageScrollViewModel
    @ObservedObject private var bannedStore = BannedPhotosStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // ── Photo Count ──
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Photos per scroll")
                            Spacer()
                            Text("\(vm.photoCount)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vm.photoCount) },
                                set: { vm.photoCount = Int($0) }
                            ),
                            in: 5...10,
                            step: 1
                        )
                        .tint(.cyan)
                    }
                } header: {
                    Text("Scroll Length")
                } footer: {
                    Text("Choose between 5 and 10 photos per generated scroll.")
                }
                
                // ── Time Frame ──
                Section {
                    ForEach(TimeFrameOption.allCases) { option in
                        Button {
                            withAnimation { vm.selectedTimeFrame = option }
                        } label: {
                            HStack {
                                Label(LocalizedStringKey(option.rawValue), systemImage: option.iconName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if vm.selectedTimeFrame == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if vm.selectedTimeFrame == .custom {
                        DatePicker(
                            "From",
                            selection: $vm.customStartDate,
                            in: ...vm.customEndDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "To",
                            selection: $vm.customEndDate,
                            in: vm.customStartDate...,
                            displayedComponents: .date
                        )
                    }
                    Divider()
                        .padding(.vertical, 4)

                    Toggle(isOn: $vm.excludePortrait) {
                        Label("Landscape Photos Only", systemImage: "rectangle.landscape")
                    }
                    .tint(.cyan)
                    .onChange(of: vm.excludePortrait) { _ in }   // takes effect on next generate

                    Toggle(isOn: $vm.evenDistribution) {
                        Label("Even Time Distribution", systemImage: "chart.bar.xaxis")
                    }
                    .tint(.cyan)
                } header: {
                    Text("Time Frame")
                } footer: {
                    if vm.evenDistribution {
                        Text("Photos are spread evenly across the selected window, with random fill for sparse periods. Takes effect on next generate.")
                    } else {
                        Text("Photos are picked randomly from the selected window with no time constraints.")
                    }
                }

                // ── Date & Location Overlays ──
                Section {
                    Toggle(isOn: $vm.showDate) {
                        Label("Show Date", systemImage: "calendar")
                    }
                    .tint(.cyan)
                    .onChange(of: vm.showDate) { _ in vm.recomposite() }

                    Toggle(isOn: $vm.showLocation) {
                        Label("Show Location", systemImage: "mappin.and.ellipse")
                    }
                    .tint(.cyan)
                    .onChange(of: vm.showLocation) { _ in vm.recomposite() }
                } header: {
                    Text("Overlays")
                } footer: {
                    Text("Date is stamped bottom-left; location (city, country) bottom-right. Photos without GPS data will not show a location.")
                }

                // ── Date Format Picker ──
                Section {
                    ForEach(DateFormatOption.allCases) { option in
                        Button {
                            vm.selectedFormat = option
                            vm.recomposite()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.rawValue)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Text(option.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if vm.selectedFormat == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Camera-style date toggle
                    Toggle(isOn: $vm.cameraDateStyle) {
                        Label("Camera Date Style", systemImage: "camera.fill")
                    }
                    .tint(.orange)
                    .onChange(of: vm.cameraDateStyle) { _ in vm.recomposite() }
                } header: {
                    Text("Date Format")
                } footer: {
                    if vm.cameraDateStyle {
                        Text("Amber digits on a near-transparent background, like a film camera date stamp.")
                    }
                }
                .disabled(!vm.showDate)
                .opacity(vm.showDate ? 1 : 0.4)

                // ── Date Size ──
                Section {
                    ForEach(DateSizeOption.allCases) { option in
                        Button {
                            vm.dateSize = option
                            vm.recomposite()
                        } label: {
                            HStack {
                                Image(systemName: option.iconName)
                                    .font(.system(size: 14))
                                    .frame(width: 24)
                                Text(LocalizedStringKey(option.rawValue))
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.primary)
                                Spacer()
                                // Preview showing relative size
                                Text("Abc")
                                    .font(.system(size: previewFontSize(for: option), weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                if vm.dateSize == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                        .padding(.leading, 4)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Date Size")
                }
                .disabled(!vm.showDate)
                .opacity(vm.showDate ? 1 : 0.4)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Scaled-down font size for the in-row preview text.
    private func previewFontSize(for option: DateSizeOption) -> CGFloat {
        switch option {
        case .small:      return 11
        case .medium:     return 14
        case .large:      return 17
        case .extraLarge: return 21
        }
    }
}
