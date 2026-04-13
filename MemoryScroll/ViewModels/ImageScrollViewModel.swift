import SwiftUI
import Photos

@MainActor
class ImageScrollViewModel: ObservableObject {

    // MARK: - State

    enum LoadState: Equatable {
        case idle, requestingAccess, loading, loaded, noPhotos, denied, error(String)
    }

    @Published var photos: [ScrollPhoto] = []
    @Published var compositeImage: UIImage?
    @Published var loadState: LoadState = .idle

    // User preferences
    @Published var showDate: Bool = true
    @Published var showLocation: Bool = false
    @Published var cameraDateStyle: Bool = false
    @Published var selectedFormat: DateFormatOption = .yyyymmdd
    @Published var dateSize: DateSizeOption = .medium
    @Published var excludePortrait: Bool = true
    @Published var photoCount: Int = 7                          // 5–10
    @Published var selectedTimeFrame: TimeFrameOption = .allTime
    @Published var selectedCategory: PhotoCategory = .all
    @Published var evenDistribution: Bool = false
    @Published var showSettings: Bool = false
    @Published var showBanSheet: Bool = false
    @Published var showCropAdjust: Bool = false
    @Published var showLocationPicker: Bool = false

    // Location filter
    @Published var availableLocations: [LocationOption] = []
    @Published var selectedLocationNames: Set<String> = []
    @Published var isLoadingLocations: Bool = false
    @Published var hasMoreLocations: Bool = false
    private var locationFetchIndex: Int = 0

    /// Union of asset IDs for all selected locations. Nil when no location filter is active.
    var locationAllowedIDs: Set<String>? {
        guard !selectedLocationNames.isEmpty else { return nil }
        return availableLocations
            .filter { selectedLocationNames.contains($0.name) }
            .reduce(into: Set<String>()) { $0.formUnion($1.assetIDs) }
    }

    /// Per-photo crop bounds keyed by ScrollPhoto.id. Reset on each new generate.
    @Published var cropBounds: [String: CropBounds] = [:]

    /// ID of the most recently generated history entry, used to update it after crop changes
    /// and to gate the Crop button in HistoryDetailView.
    private(set) var currentHistoryID: UUID?

    private let bannedStore = BannedPhotosStore.shared
    private let historyStore = HistoryStore.shared

    // Custom date range (used only when selectedTimeFrame == .custom)
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()

    // Insufficient-photos alert
    @Published var showInsufficientPhotosAlert: Bool = false
    @Published var insufficientPhotosMessage: String = ""

    // History — loaded from disk on init
    @Published var history: [HistoryItem] = HistoryStore.shared.loadAll()
    @Published var selectedTab: Tab = .create

    enum Tab: Hashable {
        case create, history, banned
    }

    // MARK: - Effective date range

    /// Resolves the active (start, end) dates based on the current time frame selection.
    var effectiveDateRange: (start: Date?, end: Date) {
        switch selectedTimeFrame {
        case .custom:
            // Ensure start is never after end
            let start = min(customStartDate, customEndDate)
            let end   = max(customStartDate, customEndDate)
            return (start, end)
        default:
            return (selectedTimeFrame.presetStartDate, Date())
        }
    }

    private var timeFrameLabel: String {
        if selectedTimeFrame == .custom {
            return NSLocalizedString("timeframe_custom", comment: "")
        }
        return "\"\(NSLocalizedString(selectedTimeFrame.rawValue, comment: ""))\""
    }

    /// Localized subject noun for the selected category, e.g. "food photos" / "美食照片".
    private var photoSubject: String {
        if selectedCategory == .all {
            return NSLocalizedString("photos", comment: "")
        }
        let categoryName = NSLocalizedString(selectedCategory.rawValue, comment: "")
        return String(format: NSLocalizedString("photo_subject_fmt", comment: ""), categoryName)
    }

    /// Alert / empty-state message when zero photos are available.
    private var zeroPhotosMessage: String {
        if selectedTimeFrame == .allTime && selectedCategory == .all {
            return NSLocalizedString("vm_empty_library", comment: "")
        }
        if selectedTimeFrame == .allTime {
            return String(format: NSLocalizedString("vm_no_subject_library", comment: ""), photoSubject)
        }
        return String(format: NSLocalizedString("vm_no_subject_timeframe", comment: ""), photoSubject, timeFrameLabel)
    }

    /// Alert / empty-state message when some photos exist but fewer than needed.
    private func insufficientMessage(found: Int) -> String {
        return String(format: NSLocalizedString("vm_insufficient", comment: ""),
                      found, photoSubject, timeFrameLabel, photoCount)
    }

    /// Subtitle shown in the empty-state view (multiline, no action prompt).
    var noPhotosEmptyStateMessage: String {
        // If a generate attempt failed and left a message, surface it directly.
        if !insufficientPhotosMessage.isEmpty { return insufficientPhotosMessage }
        let categoryName = NSLocalizedString(selectedCategory.rawValue, comment: "")
        switch selectedTimeFrame {
        case .allTime where selectedCategory == .all:
            return NSLocalizedString("vm_es_empty_library", comment: "")
        case .allTime:
            return String(format: NSLocalizedString("vm_es_no_subject_library", comment: ""), categoryName)
        case .custom where selectedCategory == .all:
            return NSLocalizedString("vm_es_all_custom", comment: "")
        case .custom:
            return String(format: NSLocalizedString("vm_es_no_subject_custom", comment: ""), categoryName)
        default:
            let tf = NSLocalizedString(selectedTimeFrame.rawValue, comment: "")
            if selectedCategory == .all {
                return String(format: NSLocalizedString("vm_es_all_timeframe", comment: ""), tf)
            }
            return String(format: NSLocalizedString("vm_es_no_subject_timeframe", comment: ""), categoryName, tf)
        }
    }

    // MARK: - Generate

    /// Full pipeline: request access → fetch photos (even buckets + random fallback) → composite → save to history.
    /// Generation is blocked entirely if the criteria cannot yield enough photos.
    func generateScroll() async {
        // Reset any leftover state from a previous attempt.
        insufficientPhotosMessage = ""
        cropBounds = [:]
        currentHistoryID = nil
        loadState = .requestingAccess
        
        

        let status = await PhotoLibraryService.requestAccess()
        switch status {
        case .denied:
            loadState = .denied
            return
        case .authorized, .limited:
            break
        case .notDetermined:
            loadState = .idle
            return
        }

        loadState = .loading
        let range = effectiveDateRange
        let result = await PhotoLibraryService.fetchPhotosEvenly(
            count: photoCount,
            from: range.start,
            to: range.end,
            category: selectedCategory,
            bannedIDs: bannedStore.bannedIDs,
            evenDistribution: evenDistribution,
            allowedIDs: locationAllowedIDs,
            excludePortrait: excludePortrait
        )

        // No photos at all in this time range.
        guard result.totalAvailable > 0 else {
            insufficientPhotosMessage = zeroPhotosMessage
            showInsufficientPhotosAlert = true
            loadState = .noPhotos
            return
        }

        // Not enough matching photos even after the random fallback — block generation.
        guard result.photos.count >= photoCount else {
            let found = result.photos.count
            insufficientPhotosMessage = found == 0
                ? zeroPhotosMessage
                : insufficientMessage(found: found)
            showInsufficientPhotosAlert = true
            loadState = .noPhotos
            return
        }

        // Full count reached — generate the scroll.
        photos = result.photos
        recomposite()
        addToHistory()
        loadState = .loaded
    }

    /// Re-render the composite without re-fetching from the photo library.
    /// Also updates the active history entry so crop changes are reflected in history.
    func recomposite() {
        guard !photos.isEmpty else { return }

        var config = ScrollCompositor.Config()
        config.showDate = showDate
        config.showLocation = showLocation
        config.dateFormat = selectedFormat.rawValue
        config.cameraDateStyle = cameraDateStyle
        config.orientation = .vertical
        config.dateFont = .monospacedSystemFont(ofSize: dateSize.fontSize, weight: .semibold)
        config.datePillInset = dateSize.pillInset
        config.cropBounds = cropBounds

        compositeImage = ScrollCompositor.composite(photos: photos, config: config)

        // Keep the live history entry in sync with the latest composite (in-memory only).
        if let id = currentHistoryID, let image = compositeImage,
           let idx = history.firstIndex(where: { $0.id == id }) {
            history[idx].image = image
        }
    }

    // MARK: - Locations

    /// Loads the first page of available locations. Safe to call multiple times —
    /// skips if already loaded or a load is in progress.
    func loadLocations() async {
        guard availableLocations.isEmpty, !isLoadingLocations else { return }
        isLoadingLocations = true
        let batch = await PhotoLibraryService.fetchAvailableLocations(startIndex: 0)
        mergeLocationBatch(batch.locations)
        locationFetchIndex = batch.nextIndex
        hasMoreLocations = batch.hasMore
        isLoadingLocations = false
    }

    /// Loads the next page of locations. No-op if already loading or nothing remains.
    func loadMoreLocations() async {
        guard !isLoadingLocations, hasMoreLocations else { return }
        isLoadingLocations = true
        let batch = await PhotoLibraryService.fetchAvailableLocations(startIndex: locationFetchIndex)
        mergeLocationBatch(batch.locations)
        locationFetchIndex = batch.nextIndex
        hasMoreLocations = batch.hasMore
        isLoadingLocations = false
    }

    /// Merges newly resolved locations into `availableLocations`, combining asset ID sets
    /// and counts for names that already exist (multiple coordinate clusters → same city).
    private func mergeLocationBatch(_ newLocations: [LocationOption]) {
        var merged: [String: LocationOption] = Dictionary(
            uniqueKeysWithValues: availableLocations.map { ($0.name, $0) }
        )
        for loc in newLocations {
            if let existing = merged[loc.name] {
                merged[loc.name] = LocationOption(
                    name: loc.name,
                    count: existing.count + loc.count,
                    assetIDs: existing.assetIDs.union(loc.assetIDs)
                )
            } else {
                merged[loc.name] = loc
            }
        }
        availableLocations = merged.values.sorted { $0.count > $1.count }
    }

    // MARK: - History

    /// Save the current composite to history and remember its ID for future crop updates.
    private func addToHistory() {
        guard let image = compositeImage else { return }
        let item = HistoryItem(
            image: image,
            photoCount: photos.count,
            orientation: .vertical,
            createdAt: Date()
        )
        currentHistoryID = item.id
        history.insert(item, at: 0)
        let store = historyStore
        Task.detached(priority: .utility) {
            store.save(item)
        }
    }

    /// Persists the current composite image to disk for the active history entry.
    /// Call this when the user finishes cropping (Done button) — not on every recomposite.
    func persistCurrentHistoryImage() {
        guard let id = currentHistoryID, let image = compositeImage else { return }
        let store = historyStore
        Task.detached(priority: .utility) {
            store.updateImage(id: id, image: image)
        }
    }

    /// Delete specific history items by their IDs.
    func deleteHistoryItems(_ ids: Set<UUID>) {
        history.removeAll { ids.contains($0.id) }
        historyStore.deleteMany(ids: ids)
    }

    /// Delete a single history item.
    func deleteHistoryItem(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        historyStore.delete(id: item.id)
    }

    /// Clear all history.
    func clearHistory() {
        history.removeAll()
        historyStore.deleteAll()
    }

    // MARK: - Helpers

    func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = selectedFormat.rawValue
        return f.string(from: date)
    }
}
