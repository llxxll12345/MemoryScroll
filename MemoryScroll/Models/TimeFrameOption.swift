import Foundation

/// Time window the user can restrict photo selection to.
enum TimeFrameOption: String, CaseIterable, Identifiable {
    case lastWeek   = "Last Week"
    case lastMonth  = "Last Month"
    case lastYear   = "Last Year"
    case last5Years = "Last 5 Years"
    case allTime    = "All Time"
    case custom     = "Custom"

    var id: String { rawValue }

    /// The earliest creation date for preset options.
    /// Returns nil for .allTime (no restriction) and .custom (VM supplies dates).
    var presetStartDate: Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .lastWeek:   return cal.date(byAdding: .weekOfYear, value: -1,  to: now)
        case .lastMonth:  return cal.date(byAdding: .month,      value: -1,  to: now)
        case .lastYear:   return cal.date(byAdding: .year,       value: -1,  to: now)
        case .last5Years: return cal.date(byAdding: .year,       value: -5,  to: now)
        case .allTime:    return nil
        case .custom:     return nil
        }
    }

    var iconName: String {
        switch self {
        case .lastWeek:   return "calendar.badge.clock"
        case .lastMonth:  return "calendar"
        case .lastYear:   return "calendar.circle"
        case .last5Years: return "calendar.circle.fill"
        case .allTime:    return "photo.stack"
        case .custom:     return "slider.horizontal.3"
        }
    }
}
