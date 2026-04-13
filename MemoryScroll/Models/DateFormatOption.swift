//
//  DateFormatOption.swift
//  MemoryScroll
//

import Foundation

/// The three date formats available for the overlay stamp.
/// Raw value doubles as the DateFormatter format string.
enum DateFormatOption: String, CaseIterable, Identifiable {
    case mmddyyyy = "MM/dd/yyyy"   // US
    case ddmmyyyy = "dd/MM/yyyy"   // European
    case yyyymmdd = "yyyy/MM/dd"   // ISO / East-Asian

    var id: String { rawValue }

    /// Example date rendered with this format (shown in settings).
    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = rawValue
        return formatter.string(from: Date())
    }
}
