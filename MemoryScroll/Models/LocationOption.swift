//
//  LocationOption.swift
//  MemoryScroll
//

import Foundation

/// A geocoded location available in the user's photo library, with the set of
/// asset local identifiers that belong to it.
struct LocationOption: Identifiable, Hashable {
    /// The human-readable name, e.g. "Kyoto, Japan".
    let name: String
    /// Number of photos at this location.
    let count: Int
    /// PHAsset local identifiers for all photos at this location.
    let assetIDs: Set<String>

    var id: String { name }

    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: LocationOption, rhs: LocationOption) -> Bool { lhs.name == rhs.name }
}
