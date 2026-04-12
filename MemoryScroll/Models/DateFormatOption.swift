//
//  DateFormatOption.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import Foundation

/// Supported date formats the user can pick from.
enum DateFormatOption: String, CaseIterable, Identifiable {
    case short      = "MM/dd/yyyy"
    case medium     = "MMM d, yyyy"
    case long       = "MMMM d, yyyy"
    case european   = "dd.MM.yyyy"
    case iso        = "yyyy-MM-dd"
    case monthYear  = "MMMM yyyy"

    var id: String { rawValue }

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = rawValue
        return formatter.string(from: Date())
    }
}
