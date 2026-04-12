import Foundation

/// Persists a set of banned PHAsset local identifiers across app restarts.
/// Banned assets are excluded from every future random selection.
class BannedPhotosStore: ObservableObject {

    static let shared = BannedPhotosStore()

    @Published private(set) var bannedIDs: Set<String> = []

    private let defaultsKey = "com.memoryscroll.bannedAssetIDs"

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        bannedIDs = Set(stored)
    }

    // MARK: - Mutations

    func ban(_ ids: Set<String>) {
        bannedIDs.formUnion(ids)
        persist()
    }

    func unban(_ ids: Set<String>) {
        bannedIDs.subtract(ids)
        persist()
    }

    func clearAll() {
        bannedIDs.removeAll()
        persist()
    }

    var count: Int { bannedIDs.count }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(Array(bannedIDs), forKey: defaultsKey)
    }
}
