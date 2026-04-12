//
//  ScrollOrientation.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import Foundation

/// Whether the composited strip scrolls vertically or horizontally.
enum ScrollOrientation: String, CaseIterable, Identifiable {
    case vertical   = "Vertical"
    case horizontal = "Horizontal"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .vertical:   return "arrow.up.and.down"
        case .horizontal: return "arrow.left.and.right"
        }
    }
}
