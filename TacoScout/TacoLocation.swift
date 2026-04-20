import Foundation
import MapKit

struct TacoLocation: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let cuisine: String
    let rating: Double
    let address: String
    let priceLevel: Int // 1 = $, 2 = $$, 3 = $$$
    let photos: [String] // URLs
    let reviews: [Review]
    let hours: BusinessHours?
    let phone: String?
    let website: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var priceString: String {
        String(repeating: "$", count: priceLevel)
    }
    
    var isOpenNow: Bool {
        guard let hours = hours else { return false }
        return hours.isOpenNow
    }
    
    static func == (lhs: TacoLocation, rhs: TacoLocation) -> Bool {
        lhs.id == rhs.id
    }
}

struct Review: Codable, Identifiable {
    var id: String { "\(authorName)-\(rating)" }
    let authorName: String
    let rating: Double
    let text: String
    let relativeTime: String
    let profilePhotoUrl: String?
}

struct BusinessHours: Codable {
    let periods: [HoursPeriod]
    let weekdayText: [String]
    
    var isOpenNow: Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now) - 1 // 0 = Sunday
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 100 + minute
        
        for period in periods {
            if period.open.day == weekday {
                let openTime = period.open.time

                if let close = period.close, close.day != weekday {
                    // Overnight: closes on the next calendar day — open if past open time
                    if currentTime >= openTime {
                        return true
                    }
                } else {
                    // Normal same-day period (or 24h with no close)
                    let closeTime = period.close?.time ?? 2359
                    if currentTime >= openTime && currentTime <= closeTime {
                        return true
                    }
                }
            } else if let close = period.close, close.day == weekday {
                // Previous day's overnight period still active until close time today
                if currentTime <= close.time {
                    return true
                }
            }
        }
        return false
    }
    
    var todayHours: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) - 1
        
        if weekday < weekdayText.count {
            let text = weekdayText[weekday]
            // Remove the day prefix like "Monday: "
            if let colonIndex = text.firstIndex(of: ":") {
                return String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            return text
        }
        return "Hours unavailable"
    }
}

struct HoursPeriod: Codable {
    let open: HoursTime
    let close: HoursTime?
}

struct HoursTime: Codable {
    let day: Int
    let time: Int
}

// MARK: - Filter Options

enum PriceFilter: Int, CaseIterable, Identifiable {
    case any = 0
    case cheap = 1
    case moderate = 2
    case expensive = 3
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .any: return "Any"
        case .cheap: return "$"
        case .moderate: return "$$"
        case .expensive: return "$$$"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case distance = "Distance"
    case rating = "Rating"
    case price = "Price"
    
    var id: String { rawValue }
}

struct FilterState: Equatable {
    var minRating: Double = 0
    var priceFilter: PriceFilter = .any
    var openNowOnly: Bool = false
    var sortBy: SortOption = .distance
    var maxDistance: Double = 25.0 // miles — synced from search radius on appear
}
