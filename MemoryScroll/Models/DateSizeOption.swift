//
//  DateSizeOption.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import Foundation

/// Controls the font size of the date stamp on the composited image.
enum DateSizeOption: String, CaseIterable, Identifiable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"
    case extraLarge = "Extra Large"

    var id: String { rawValue }

    /// The actual font point size used when rendering on the composite image.
    var fontSize: CGFloat {
        switch self {
        case .small:      return 20
        case .medium:     return 28
        case .large:      return 38
        case .extraLarge: return 60
        }
    }

    /// Inner padding inside the date pill, scaled to font size.
    var pillInset: CGFloat {
        switch self {
        case .small:      return 5
        case .medium:     return 8
        case .large:      return 10
        case .extraLarge: return 14
        }
    }

    var iconName: String {
        switch self {
        case .small:      return "textformat.size.smaller"
        case .medium:     return "textformat.size"
        case .large:      return "textformat.size.larger"
        case .extraLarge: return "textformat.size.larger"
        }
    }
}
