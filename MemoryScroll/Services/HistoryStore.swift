//
//  HistoryStore.swift
//  MemoryScroll
//

import UIKit

/// Persists scroll history across app launches.
///
/// - Images are stored as JPEG files under Documents/history_images/
/// - Metadata (id, filename, photoCount, orientation, date) is stored as
///   a JSON array in UserDefaults.
///
/// All writes are synchronous and cheap (metadata only); image I/O happens
/// on the call site (typically a background Task from the ViewModel).
class HistoryStore {
    static let shared = HistoryStore()

    private let metadataKey = "com.memoryscroll.historyMetadata"
    private let imagesDir: URL

    // MARK: - Codable record stored in UserDefaults

    private struct Record: Codable {
        let id: UUID
        let imageFileName: String
        let photoCount: Int
        let orientationRaw: String
        let createdAt: Date
    }

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDir = docs.appendingPathComponent("history_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    // MARK: - Load

    /// Loads all persisted items, oldest-first, then reverses to newest-first.
    /// Items whose image file is missing are silently dropped.
    func loadAll() -> [HistoryItem] {
        guard
            let data = UserDefaults.standard.data(forKey: metadataKey),
            let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }

        return records.compactMap { record in
            let url = imagesDir.appendingPathComponent(record.imageFileName)
            guard
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data),
                let orientation = ScrollOrientation(rawValue: record.orientationRaw)
            else { return nil }

            return HistoryItem(
                id: record.id,
                image: image,
                photoCount: record.photoCount,
                orientation: orientation,
                createdAt: record.createdAt
            )
        }
    }

    // MARK: - Save

    /// Persists a new item. The image is written to disk; metadata is appended to UserDefaults.
    func save(_ item: HistoryItem) {
        let fileName = "\(item.id.uuidString).jpg"
        let url = imagesDir.appendingPathComponent(fileName)

        guard let data = item.image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url, options: .atomic)

        var records = loadRecords()
        records.insert(Record(
            id: item.id,
            imageFileName: fileName,
            photoCount: item.photoCount,
            orientationRaw: item.orientation.rawValue,
            createdAt: item.createdAt
        ), at: 0)
        saveRecords(records)
    }

    // MARK: - Update image

    /// Overwrites the image file for an existing item (e.g. after a crop adjustment).
    /// Must be called from a background context — JPEG encoding + file I/O are expensive.
    func updateImage(id: UUID, image: UIImage) {
        let fileName = "\(id.uuidString).jpg"
        let url = imagesDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Delete

    func delete(id: UUID) {
        removeImageFile(id: id)
        var records = loadRecords()
        records.removeAll { $0.id == id }
        saveRecords(records)
    }

    func deleteMany(ids: Set<UUID>) {
        ids.forEach { removeImageFile(id: $0) }
        var records = loadRecords()
        records.removeAll { ids.contains($0.id) }
        saveRecords(records)
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: imagesDir)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: metadataKey)
    }

    // MARK: - Helpers

    private func loadRecords() -> [Record] {
        guard
            let data = UserDefaults.standard.data(forKey: metadataKey),
            let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
        return records
    }

    private func saveRecords(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }

    private func removeImageFile(id: UUID) {
        let url = imagesDir.appendingPathComponent("\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
