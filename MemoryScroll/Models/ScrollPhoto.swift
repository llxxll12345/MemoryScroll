//
//  ScrollPhoto.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import UIKit
import Photos
 
/// Represents one photo selected from the user's library.
struct ScrollPhoto: Identifiable {
    let id: String              // PHAsset localIdentifier
    let asset: PHAsset
    let image: UIImage          // Full-resolution image
    let creationDate: Date
    /// Human-readable location resolved via reverse geocoding, e.g. "Kyoto, Japan".
    /// Nil when the asset has no GPS data or geocoding failed.
    let locationName: String?

    /// Whether the original photo is landscape orientation.
    var isLandscape: Bool {
        asset.pixelWidth > asset.pixelHeight
    }

    /// Aspect ratio (width / height) of the original asset.
    var aspectRatio: CGFloat {
        CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }
}
