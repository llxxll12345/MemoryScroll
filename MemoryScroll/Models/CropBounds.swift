//
//  CropBounds.swift
//  MemoryScroll
//

import Foundation

/// Represents how much to trim from the top and bottom of a photo's strip slot.
/// Both values are normalized fractions (0.0 = no trim, up to < 1.0).
/// The sum of top + bottom must always be < 1 so at least some of the photo remains visible.
struct CropBounds: Equatable {
    /// Fraction trimmed from the top (0 = none, 0.5 = half).
    var top: CGFloat
    /// Fraction trimmed from the bottom (0 = none, 0.5 = half).
    var bottom: CGFloat

    static let zero = CropBounds(top: 0, bottom: 0)

    /// Clamps both values so their sum never reaches 1 (minimum 5% visible).
    mutating func clamp() {
        top    = max(0, min(top,    0.95))
        bottom = max(0, min(bottom, 0.95))
        let total = top + bottom
        if total >= 0.95 {
            let scale = 0.94 / total
            top    *= scale
            bottom *= scale
        }
    }
}
