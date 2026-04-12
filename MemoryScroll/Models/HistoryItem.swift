//
//  HistoryItem.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import UIKit

/// A previously generated scroll image kept in memory for the session.
struct HistoryItem: Identifiable {
    let id: UUID
    var image: UIImage
    let photoCount: Int
    let orientation: ScrollOrientation
    let createdAt: Date

    /// Convenience init for new items — generates a fresh UUID.
    init(image: UIImage, photoCount: Int, orientation: ScrollOrientation, createdAt: Date) {
        self.id = UUID()
        self.image = image
        self.photoCount = photoCount
        self.orientation = orientation
        self.createdAt = createdAt
    }

    /// Full init used when rehydrating from disk.
    init(id: UUID, image: UIImage, photoCount: Int, orientation: ScrollOrientation, createdAt: Date) {
        self.id = id
        self.image = image
        self.photoCount = photoCount
        self.orientation = orientation
        self.createdAt = createdAt
    }
 
    /// Thumbnail for the history grid (downscaled for performance).
    var thumbnail: UIImage {
        let maxDim: CGFloat = 400
        let scale: CGFloat
        if image.size.width > image.size.height {
            scale = maxDim / image.size.width
        } else {
            scale = maxDim / image.size.height
        }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
 
