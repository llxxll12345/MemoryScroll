import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ImageScrollViewModel()
    @State private var showShareSheet = false
    @State private var showCategoryPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabPicker
                tabContent
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.showSettings) {
            SettingsSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = vm.compositeImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showBanSheet) {
            BanSelectionSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showLocationPicker) {
            LocationPickerSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showCropAdjust) {
            CropAdjustSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Not Enough Photos", isPresented: $vm.showInsufficientPhotosAlert) {
            Button("Category") { showCategoryPicker = true }
            Button("Time Frame") { vm.showSettings = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.insufficientPhotosMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memory Scroll")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Random photo strip generator")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Button { vm.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Create", icon: "plus.square", tab: .create)
            tabButton(title: "History", icon: "clock.arrow.circlepath", tab: .history,
                      badge: vm.history.count)
            tabButton(title: "Banned", icon: "hand.raised.fill", tab: .banned,
                      badge: vm.history.count)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func tabButton(title: LocalizedStringKey, icon: String, tab: ImageScrollViewModel.Tab, badge: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { vm.selectedTab = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if badge > 0 && tab == .history {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(vm.selectedTab == tab ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            vm.selectedTab == tab ? .white.opacity(0.3) : .white.opacity(0.1),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(vm.selectedTab == tab ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                vm.selectedTab == tab ? Color.white.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .create:
            VStack(spacing: 0) {
                Spacer()
                createContent
                Spacer()
                createBottomBar
            }
        case .history:
            HistoryView(vm: vm)
        case .banned:
            BannedPhotosView()
        }
    }

    // MARK: - Create Tab Content

    @ViewBuilder
    private var createContent: some View {
        switch vm.loadState {
        case .idle:
            emptyState(
                icon: "photo.on.rectangle.angled",
                title: "Generate a Scroll",
                subtitle: NSLocalizedString("Tap the button below to pick random\nphotos from your library.", comment: "")
            )

        case .requestingAccess, .loading:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                if vm.loadState == .requestingAccess {
                    Text("Requesting access…")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text("Building your scroll…")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

        case .loaded:
            if let image = vm.compositeImage {
                VStack(spacing: 12) {
                    ScrollStripView(image: image, orientation: vm.orientation)
                        .frame(maxHeight: vm.orientation == .vertical ? 420 : 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16)
                        .shadow(color: .white.opacity(0.04), radius: 20)

                    HStack(spacing: 8) {
                        Image(systemName: vm.orientation.iconName)
                            .font(.system(size: 11))
                        Text("\(vm.photos.count) photos  ·  \(Int(image.size.width))×\(Int(image.size.height)) px")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                }
            }

        case .noPhotos:
            emptyState(
                icon: "photo.badge.exclamationmark",
                title: "No Photos Found",
                subtitle: vm.noPhotosEmptyStateMessage
            )

        case .denied:
            emptyState(
                icon: "lock.shield",
                title: "Access Denied",
                subtitle: NSLocalizedString("Grant photo library access in\nSettings → Privacy → Photos.", comment: "")
            )

        case .error(let msg):
            emptyState(
                icon: "exclamationmark.triangle",
                title: "Something Went Wrong",
                subtitle: msg
            )
        }
    }

    private func emptyState(icon: String, title: LocalizedStringKey, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text(subtitle)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Create Bottom Bar

    private var createBottomBar: some View {
        HStack(spacing: 12) {
            // Generate / Shuffle
            Button {
                Task { await vm.generateScroll() }
            } label: {
                Image(systemName: vm.loadState == .loaded
                      ? "arrow.trianglehead.2.clockwise"
                      : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(.white, in: Capsule())
            }
            .disabled(vm.loadState == .loading || vm.loadState == .requestingAccess)

            // Category picker
            Button { showCategoryPicker = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: vm.selectedCategory.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(vm.selectedCategory == .all ? .white.opacity(0.7) : .cyan)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                    if vm.selectedCategory != .all {
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: 2, y: -2)
                    }
                }
            }

            // Location filter
            Button { vm.showLocationPicker = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(vm.selectedLocationNames.isEmpty ? .white.opacity(0.7) : .cyan)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                    if !vm.selectedLocationNames.isEmpty {
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: 2, y: -2)
                    }
                }
            }

            Spacer()

            // Overflow menu — post-generation actions
            if vm.loadState == .loaded, !vm.photos.isEmpty {
                Menu {
                    Button { vm.showCropAdjust = true } label: {
                        Label(
                            LocalizedStringKey(vm.cropBounds.isEmpty ? "Adjust Crops" : "Adjust Crops (active)"),
                            systemImage: "crop"
                        )
                    }
                    Button { vm.showBanSheet = true } label: {
                        Label("Ban Photos", systemImage: "hand.raised.fill")
                    }
                    Divider()
                    Button { showShareSheet = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    if let image = vm.compositeImage {
                        Button {
                            Task { await PhotoLibraryService.saveImageToAppAlbum(image) }
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.08), in: Circle())
                            if !vm.cropBounds.isEmpty {
                                Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: 2, y: -2)
                            }
                        }
                        Text("Actions")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.loadState)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 10)
    }
}

// MARK: - UIKit Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
