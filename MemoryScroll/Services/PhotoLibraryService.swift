//
//  PhotoLibraryService.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import Photos
import UIKit
import Vision
import CoreLocation

/// Handles photo library authorization, fetching random images,
/// and saving generated scrolls to a dedicated album so they can
/// be excluded from future random selections.
class PhotoLibraryService {

    enum AuthStatus {
        case notDetermined, authorized, limited, denied
    }

    /// Name of the album used to store app-generated scroll images.
    private static let albumName = "Memory Scroll"

    /// Session-level cache: "assetID:categoryRawValue" → matches category?
    /// Avoids re-running Vision inference on the same asset in the same session.
    private static var classificationCache: [String: Bool] = [:]

    /// Session-level cache: "lat2dp,lon2dp" → resolved location name.
    /// Avoids redundant CLGeocoder calls for nearby photos.
    private static var geocodeCache: [String: String] = [:]

    /// Coordinate clusters built once per session from the full photo library.
    /// Each element is (coordinateKey, assetIDs, representative CLLocation).
    private static var cachedClusters: [(key: String, assetIDs: [String], loc: CLLocation)]? = nil

    // MARK: - Authorization

    /// Request photo library access. Returns the resolved status.
    static func requestAccess() async -> AuthStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch newStatus {
            case .authorized: return .authorized
            case .limited:    return .limited
            default:          return .denied
            }
        @unknown default:
            return .denied
        }
    }

    // MARK: - Photo Fetch

    /// Fetches photos from the library within the given date range.
    ///
    /// When `evenDistribution` is `true`, the range is divided into `count` equal
    /// time buckets and one photo is picked per bucket, producing a scroll that spans
    /// the full period evenly. Any gaps are back-filled with random photos from the
    /// full range (Phase 2 fallback).
    ///
    /// When `evenDistribution` is `false`, photos are picked randomly from the full
    /// date range with no temporal constraint (Phase 2 only).
    ///
    /// - Parameters:
    ///   - count: Number of photos to select.
    ///   - startDate: Start of the range. Pass `nil` to anchor at the oldest eligible photo.
    ///   - endDate: End of the range (defaults to now).
    ///   - category: Content category filter. Defaults to `.all` (no filtering).
    ///   - bannedIDs: Asset identifiers to exclude from selection.
    ///   - evenDistribution: When `true`, spreads selections evenly across time buckets.
    /// - Returns: The selected photos and the total eligible (pre-category-filter) photo count.
    static func fetchPhotosEvenly(
        count: Int,
        from startDate: Date?,
        to endDate: Date = Date(),
        category: PhotoCategory = .all,
        bannedIDs: Set<String> = [],
        evenDistribution: Bool = false,
        allowedIDs: Set<String>? = nil,   // nil = no location filter; non-nil = only these assets
        excludePortrait: Bool = true       // when true, photos taller than wide are skipped
    ) async -> (photos: [ScrollPhoto], totalAvailable: Int) {
        // Merge app-album IDs and user-banned IDs into one exclusion set.
        let excludedIDs = fetchAppAlbumAssetIDs().union(bannedIDs)

        let useVision = category != .all
        // Build the label set once so classifyAsset doesn't recreate it per call.
        let labelSet: Set<String> = useVision ? Set(category.visionLabels) : []

        // Determine effective start: anchor to oldest eligible photo for "All Time".
        let effectiveStart: Date
        if let startDate {
            effectiveStart = startDate
        } else if let oldest = oldestEligiblePhotoDate(excludedIDs: excludedIDs) {
            effectiveStart = oldest
        } else {
            return ([], 0)
        }

        guard endDate > effectiveStart else { return ([], 0) }

        let manager = PHImageManager.default()
        let reqOptions = PHImageRequestOptions()
        reqOptions.isSynchronous = false
        reqOptions.deliveryMode  = .highQualityFormat
        reqOptions.isNetworkAccessAllowed = true
        reqOptions.resizeMode    = .exact

        var results: [ScrollPhoto] = []
        var usedAssetIDs = Set<String>()   // tracks every asset already added to results
        var totalAvailable = 0

        // ── Phase 1: Even time-bucket distribution (optional) ───────────────────
        if evenDistribution {
            let totalInterval = endDate.timeIntervalSince(effectiveStart)
            let bucketSize    = totalInterval / Double(count)

            for i in 0..<count {
                let bucketStart = effectiveStart.addingTimeInterval(Double(i)     * bucketSize)
                let bucketEnd   = effectiveStart.addingTimeInterval(Double(i + 1) * bucketSize)

                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    bucketStart as NSDate,
                    bucketEnd   as NSDate
                )

                let assets = PHAsset.fetchAssets(with: fetchOptions)

                var eligible: [PHAsset] = []
                for j in 0..<assets.count {
                    let asset = assets.object(at: j)
                    guard !excludedIDs.contains(asset.localIdentifier) else { continue }
                    if let allowed = allowedIDs, !allowed.contains(asset.localIdentifier) { continue }
                    if excludePortrait && asset.pixelHeight > asset.pixelWidth { continue }
                    eligible.append(asset)
                }

                totalAvailable += eligible.count

                // Find one matching photo for this bucket.
                let picked: PHAsset?
                if useVision {
                    var match: PHAsset? = nil
                    for candidate in eligible.shuffled() {
                        if await classifyAsset(candidate, labelSet: labelSet, cacheKey: category.rawValue) {
                            match = candidate
                            break
                        }
                    }
                    picked = match
                } else {
                    picked = eligible.randomElement()
                }

                guard let asset = picked else { continue }
                usedAssetIDs.insert(asset.localIdentifier)

                if let photo = await loadScrollPhoto(for: asset, fallbackDate: bucketStart, options: reqOptions, manager: manager) {
                    results.append(photo)
                }
            }
        }

        // ── Phase 2: Random fill ─────────────────────────────────────────────────
        // When evenDistribution is off: fills all `count` slots from the full range.
        // When evenDistribution is on: back-fills any gaps left by sparse time buckets.
        if results.count < count {
            let needed = count - results.count

            let fallbackOpts = PHFetchOptions()
            fallbackOpts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fallbackOpts.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate >= %@ AND creationDate <= %@",
                PHAssetMediaType.image.rawValue,
                effectiveStart as NSDate,
                endDate        as NSDate
            )

            let allAssets = PHAsset.fetchAssets(with: fallbackOpts)

            // Build a pool of unused, eligible assets.
            // Also tally totalAvailable here when Phase 1 was skipped.
            var pool: [PHAsset] = []
            for i in 0..<allAssets.count {
                let asset = allAssets.object(at: i)
                guard !excludedIDs.contains(asset.localIdentifier) else { continue }
                if let allowed = allowedIDs, !allowed.contains(asset.localIdentifier) { continue }
                if excludePortrait && asset.pixelHeight > asset.pixelWidth { continue }
                if !evenDistribution { totalAvailable += 1 }
                if !usedAssetIDs.contains(asset.localIdentifier) {
                    pool.append(asset)
                }
            }

            // Filter by category, then pick up to `needed`.
            var fallbackPicks: [PHAsset] = []
            if useVision {
                for candidate in pool.shuffled() {
                    if fallbackPicks.count >= needed { break }
                    if await classifyAsset(candidate, labelSet: labelSet, cacheKey: category.rawValue) {
                        fallbackPicks.append(candidate)
                    }
                }
            } else {
                fallbackPicks = Array(pool.shuffled().prefix(needed))
            }

            for asset in fallbackPicks {
                usedAssetIDs.insert(asset.localIdentifier)
                if let photo = await loadScrollPhoto(for: asset, fallbackDate: Date(), options: reqOptions, manager: manager) {
                    results.append(photo)
                }
            }
        }

        results.sort { $0.creationDate < $1.creationDate }
        return (results, totalAvailable)
    }

    // MARK: - Save to App Album

    /// Save an image to the camera roll AND add it to the "Memory Scroll" album.
    static func saveImageToAppAlbum(_ image: UIImage) async -> Bool {
        let album = fetchOrCreateAppAlbum()
        guard let album else { return false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
            }
            return true
        } catch {
            print("Failed to save image to app album: \(error)")
            return false
        }
    }

    // MARK: - Vision Classification

    /// Classifies a single asset using Vision's on-device image classifier.
    /// - Parameters:
    ///   - asset: The asset to classify.
    ///   - labelSet: Pre-built Set of exact Vision label identifiers to match against.
    ///   - cacheKey: Category raw value used as part of the session cache key.
    /// - Returns: `true` if any observation with confidence ≥ 0.25 exactly matches a label.
    private static func classifyAsset(
        _ asset: PHAsset,
        labelSet: Set<String>,
        cacheKey categoryKey: String
    ) async -> Bool {
        let cacheKey = "\(asset.localIdentifier):\(categoryKey)"
        if let cached = classificationCache[cacheKey] { return cached }

        // Load a small thumbnail — fast, sufficient for classification.
        let thumbOptions = PHImageRequestOptions()
        thumbOptions.deliveryMode = .fastFormat
        thumbOptions.isSynchronous = false
        thumbOptions.isNetworkAccessAllowed = false
        thumbOptions.resizeMode = .fast

        guard let thumb = await loadImage(
            for: asset,
            targetSize: CGSize(width: 224, height: 224),
            options: thumbOptions,
            manager: PHImageManager.default()
        ), let cgImage = thumb.cgImage else {
            classificationCache[cacheKey] = false
            return false
        }
        
        let result: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    
                    // Use exact label matching — no substring ambiguity (e.g. "sky" ≠ "skyscraper").
                    let matches = observations.contains { obs in
                        obs.confidence >= 0.25 && labelSet.contains(obs.identifier)
                    }
                    continuation.resume(returning: matches)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }

        classificationCache[cacheKey] = result
        return result
    }

    // MARK: - Album Helpers

    private static func fetchAppAlbumAssetIDs() -> Set<String> {
        guard let album = findAppAlbum() else { return [] }
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        var ids = Set<String>()
        assets.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        return ids
    }

    private static func findAppAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title == %@", albumName)
        return PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions
        ).firstObject
    }
    
    private static func fetchOrCreateAppAlbum() -> PHAssetCollection? {
        if let existing = findAppAlbum() { return existing }

        var albumID: String?
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumID = request.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch {
            print("Failed to create app album: \(error)")
            return nil
        }

        guard let id = albumID else { return nil }
        return PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [id], options: nil
        ).firstObject
    }

    // MARK: - Location Index

    /// Result of a single location-fetch batch.
    struct LocationBatch {
        /// New `LocationOption` values resolved in this batch (may overlap with prior
        /// batches by name — callers should merge by name).
        let locations: [LocationOption]
        /// Index to pass as `startIndex` for the next batch.
        let nextIndex: Int
        /// `true` if more clusters remain beyond `nextIndex`.
        let hasMore: Bool
    }

    /// Geocodes one batch of coordinate clusters (up to `limit` uncached API calls) and
    /// returns the resolved locations together with a cursor for the next batch.
    ///
    /// Clusters are built from the full photo library on the first call and cached for the
    /// session; subsequent calls reuse the list and skip already-geocoded clusters.
    ///
    /// - Parameters:
    ///   - startIndex: Cluster index to begin from (0 for the first page).
    ///   - limit: Maximum number of **uncached** geocoding API calls to make. Cached
    ///            hits are free and do not count toward this limit.
    static func fetchAvailableLocations(startIndex: Int = 0, limit: Int = 45) async -> LocationBatch {
        // Build (or reuse) the sorted cluster list.
        let clusters: [(key: String, assetIDs: [String], loc: CLLocation)]
        if let cached = cachedClusters {
            clusters = cached
        } else {
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let assets = PHAsset.fetchAssets(with: opts)

            var coordToAssetIDs: [String: [String]] = [:]
            var coordToLocation:  [String: CLLocation]  = [:]

            for i in 0..<assets.count {
                let asset = assets.object(at: i)
                guard let loc = asset.location else { continue }
                let key = String(format: "%.2f,%.2f",
                                 loc.coordinate.latitude,
                                 loc.coordinate.longitude)
                coordToAssetIDs[key, default: []].append(asset.localIdentifier)
                if coordToLocation[key] == nil { coordToLocation[key] = loc }
            }

            // Largest clusters first so popular locations appear on the first page.
            clusters = coordToAssetIDs
                .sorted { $0.value.count > $1.value.count }
                .compactMap { entry -> (String, [String], CLLocation)? in
                    guard let loc = coordToLocation[entry.key] else { return nil }
                    return (entry.key, entry.value, loc)
                }
            cachedClusters = clusters
        }

        guard startIndex < clusters.count else {
            return LocationBatch(locations: [], nextIndex: startIndex, hasMore: false)
        }

        // Walk clusters starting at `startIndex`, stopping once we've made `limit`
        // uncached API calls. Cache hits are free and never consume from the limit.
        var nameToAssetIDs: [String: Set<String>] = [:]
        var uncachedCallsMade = 0
        var endIndex = startIndex

        for idx in startIndex..<clusters.count {
            let (_, assetIDs, loc) = clusters[idx]
            let cacheKey = String(format: "%.2f,%.2f",
                                  loc.coordinate.latitude,
                                  loc.coordinate.longitude)
            let isCached = geocodeCache[cacheKey] != nil

            if !isCached {
                if uncachedCallsMade >= limit {
                    break   // leave remaining clusters for the next batch
                }
                uncachedCallsMade += 1
            }

            endIndex = idx + 1
            guard let name = await resolveLocationName(for: loc) else { continue }
            for id in assetIDs {
                nameToAssetIDs[name, default: []].insert(id)
            }
        }

        let locations = nameToAssetIDs
            .map { LocationOption(name: $0.key, count: $0.value.count, assetIDs: $0.value) }
            .sorted { $0.count > $1.count }

        return LocationBatch(locations: locations, nextIndex: endIndex, hasMore: endIndex < clusters.count)
    }

    // MARK: - Private Helpers

    /// Returns the creation date of the oldest photo not in the excluded set.
    private static func oldestEligiblePhotoDate(excludedIDs: Set<String>) -> Date? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.fetchLimit = 200

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            if !excludedIDs.contains(asset.localIdentifier) { return asset.creationDate }
        }
        return nil
    }

    /// Loads the full-resolution image for an asset, resolves its location name,
    /// and returns a fully populated ScrollPhoto. Returns nil if the image load fails.
    /// Portrait photos (height > width) are center-cropped to a 16:9 window.
    private static func loadScrollPhoto(
        for asset: PHAsset,
        fallbackDate: Date,
        options: PHImageRequestOptions,
        manager: PHImageManager
    ) async -> ScrollPhoto? {
        let targetHeight: CGFloat = 800
        let aspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        let targetSize  = CGSize(width: targetHeight * aspectRatio, height: targetHeight)

        guard let image = await loadImage(for: asset, targetSize: targetSize, options: options, manager: manager) else {
            return nil
        }

        let locationName: String?
        if let location = asset.location {
            locationName = await resolveLocationName(for: location)
        } else {
            locationName = nil
        }

        return ScrollPhoto(
            id: asset.localIdentifier,
            asset: asset,
            image: image,
            creationDate: asset.creationDate ?? fallbackDate,
            locationName: locationName
        )
    }

    /// Reverse-geocodes a CLLocation to a human-readable "City, Country" string.
    /// Results are cached by coordinate (2 decimal places) for the session.
    private static func resolveLocationName(for location: CLLocation) async -> String? {
        let key = String(format: "%.2f,%.2f",
                         location.coordinate.latitude,
                         location.coordinate.longitude)
        if let cached = geocodeCache[key] { return cached }

        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let name: String?
                switch (placemark.locality, placemark.country) {
                case let (city?, country?): name = "\(city), \(country)"
                case let (nil, country?):   name = country
                default:                    name = nil
                }
                if let name { geocodeCache[key] = name }
                continuation.resume(returning: name)
            }
        }
    }

    /// Async wrapper around PHImageManager's requestImage.
    private static func loadImage(
        for asset: PHAsset,
        targetSize: CGSize,
        options: PHImageRequestOptions,
        manager: PHImageManager
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded { continuation.resume(returning: image) }
            }
        }
    }
}
